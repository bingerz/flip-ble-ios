import CoreBluetooth
import Foundation

@available(iOS 13.0, *)
public struct BLEAdvertisement {
    public let peripheral: BLEPeripheral
    public let advertisementData: [String: Any]
    public let rssi: NSNumber?

    public var localName: String? {
        advertisementData[CBAdvertisementDataLocalNameKey] as? String
    }

    public var serviceUUIDs: [CBUUID] {
        advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
    }

    public var manufacturerData: Data? {
        advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
    }

    public var isConnectable: Bool {
        (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? false
    }
}

@available(iOS 13.0, *)
public enum BLEConnectionEvent {
    case retrieved(BLEPeripheral)
    case retrievedConnected(BLEPeripheral)
    case restored(BLEPeripheral)
    case connecting(BLEPeripheral)
    case connected(BLEPeripheral)
    case failed(BLEPeripheral, BLEError)
    case disconnected(BLEPeripheral, BLEError?)
}

@available(iOS 13.0, *)
public final class BLECentral: NSObject {
    public static let shared = BLECentral()

    private let manager = BZCentralManager.default()
    private let bridge = BLECentralBridge()
    private let lock = NSLock()
    private var scanContinuations: [String: AsyncStream<BLEAdvertisement>.Continuation] = [:]
    private var stateContinuations: [String: AsyncStream<CBManagerState>.Continuation] = [:]
    private var connectionContinuations: [String: AsyncStream<BLEConnectionEvent>.Continuation] = [:]
    private var connectContinuations: [String: CheckedContinuation<Void, Error>] = [:]
    private var disconnectContinuations: [String: CheckedContinuation<Void, Never>] = [:]
    private var wrappers: [String: BLEPeripheral] = [:]
    private var pendingScan: PendingScan?
    private var scanGeneration: UInt = 0

    private override init() {
        super.init()
        bridge.owner = self
    }

    public func start(restoreIdentifier: String?, showPowerAlert: Bool) {
        manager.centralStateDelegate = bridge
        manager.scanDelegate = bridge
        manager.startCentral(withRestoreIdKey: restoreIdentifier, showPowerAlert: showPowerAlert)
    }

    public func destroy() {
        stopScan()
        finishConnections()
        manager.destroyCentral()
    }

    public func restart(restoreIdentifier: String?, showPowerAlert: Bool) {
        lock.lock()
        wrappers.removeAll()
        lock.unlock()
        manager.centralStateDelegate = bridge
        manager.scanDelegate = bridge
        manager.restartCentral(withRestoreIdKey: restoreIdentifier, showPowerAlert: showPowerAlert)
    }

    public var isPoweredOn: Bool {
        manager.isStatePoweredOn()
    }

    public var state: CBManagerState {
        manager.centralManager?.state ?? .unknown
    }

    public var isScanning: Bool {
        manager.isScanning
    }

    public func observeState() -> AsyncStream<CBManagerState> {
        stream(into: \.stateContinuations, initial: state)
    }

    public func observeConnections() -> AsyncStream<BLEConnectionEvent> {
        stream(into: \.connectionContinuations)
    }

    public func scan(services: [CBUUID], allowDuplicates: Bool = false) -> AsyncStream<BLEAdvertisement> {
        let advertisements = openScanStream()
        let generation = rememberScan(services: services, allowDuplicates: allowDuplicates)
        manager.scanDelegate = bridge
        startPendingScan(generation)
        return advertisements
    }

    public func stopScan() {
        lock.lock()
        scanGeneration &+= 1
        pendingScan = nil
        lock.unlock()
        manager.stopScan()
        finish(\.scanContinuations)
    }

    public func connect(_ peripheral: BLEPeripheral) async throws {
        if peripheral.isConnected {
            return
        }
        guard manager.centralManager != nil else {
            throw BLEError.invalidOperation("Central is not started")
        }
        try await withCheckedThrowingContinuation { continuation in
            let id = key(for: peripheral.peripheral)
            lock.lock()
            if let previous = connectContinuations.removeValue(forKey: id) {
                previous.resume(throwing: BLEError.invalidOperation("Connect replaced"))
            }
            connectContinuations[id] = continuation
            lock.unlock()
            track(peripheral)
            if !peripheral.peripheral.connect() {
                resumeConnect(id, result: .failure(BLEError.invalidOperation("Connect did not start")))
            }
        }
    }

    public func disconnect(_ peripheral: BLEPeripheral) async {
        guard peripheral.isConnected else { return }
        await withCheckedContinuation { continuation in
            let id = key(for: peripheral.peripheral)
            lock.lock()
            disconnectContinuations[id] = continuation
            lock.unlock()
            peripheral.peripheral.connectStateDelegate = bridge
            if !peripheral.peripheral.disconnect() {
                resumeDisconnect(id)
            }
        }
    }

    public func track(_ peripheral: BLEPeripheral) {
        let id = peripheral.uuidString
        if !id.isEmpty, let existing = manager.getPeripheral(id) {
            existing.connectStateDelegate = bridge
            remember(existing === peripheral.peripheral ? peripheral : BLEPeripheral(existing))
            return
        }
        peripheral.peripheral.connectStateDelegate = bridge
        manager.add(peripheral.peripheral)
        remember(peripheral)
    }

    public func untrack(_ peripheral: BLEPeripheral) {
        if peripheral.peripheral.connectStateDelegate as AnyObject? === bridge {
            peripheral.peripheral.connectStateDelegate = nil
        }
        manager.remove(peripheral.peripheral)
        forget(peripheral)
    }

    public func peripheral(identifier: String) -> BLEPeripheral? {
        guard !identifier.isEmpty, let found = manager.getPeripheral(identifier) else {
            return nil
        }
        if let cached = cachedWrapper(identifier), cached.peripheral === found {
            return cached
        }
        let wrapped = BLEPeripheral(found)
        remember(wrapped)
        return wrapped
    }

    public var peripherals: [BLEPeripheral] {
        BZMultiplePeripheralController.sharedInstance.getPeripherals().map { wrap($0) }
    }

    public func disconnectAll() {
        BZMultiplePeripheralController.sharedInstance.disconnectAllPeripheral()
    }

    public func registerRetrieved(_ peripheral: BLEPeripheral) {
        register(peripheral, connected: false)
    }

    public func registerRetrievedConnected(_ peripheral: BLEPeripheral) {
        register(peripheral, connected: true)
    }

    public func retrievePeripherals(identifiers: [String]) -> [BLEPeripheral] {
        (manager.retrievePeripherals(identifiers) ?? []).map { presented($0) }
    }

    public func retrieveConnectedPeripherals(services: [CBUUID]) -> [BLEPeripheral] {
        (manager.retrieveConnectedPeripherals(services) ?? []).map { presented($0) }
    }

    func openScanStream() -> AsyncStream<BLEAdvertisement> {
        stream(into: \.scanContinuations)
    }

    func presented(_ peripheral: BZPeripheral) -> BLEPeripheral {
        let id = peripheral.uuidString ?? ""
        if !id.isEmpty, manager.getPeripheral(id) != nil {
            return wrap(peripheral)
        }
        return BLEPeripheral(peripheral)
    }

    var pendingScanServiceUUIDs: [CBUUID]? {
        lock.lock()
        let services = pendingScan?.services
        lock.unlock()
        return services
    }

    var pendingScanAllowsDuplicates: Bool {
        lock.lock()
        let allowsDuplicates = pendingScan?.allowDuplicates ?? false
        lock.unlock()
        return allowsDuplicates
    }

    func centralDidUpdate(_ state: CBManagerState) {
        yield(state, from: \.stateContinuations)
        guard state == .poweredOn else { return }
        lock.lock()
        let generation = scanGeneration
        lock.unlock()
        startPendingScan(generation)
    }

    func didScanning(_ peripheral: BZPeripheral, advData: [String: Any]) {
        let wrapped = wrap(peripheral)
        if let rssi = peripheral.scannedRSSINumber {
            wrapped.rssi = rssi
            wrapped.peripheral.scannedRSSINumber = rssi
        }
        let advertisement = BLEAdvertisement(
            peripheral: wrapped,
            advertisementData: advData,
            rssi: peripheral.scannedRSSINumber
        )
        yield(advertisement, from: \.scanContinuations)
    }

    func didConnecting(_ peripheral: BZPeripheral) {
        emit(.connecting(wrap(peripheral)))
    }

    func didConnected(_ peripheral: BZPeripheral) {
        emit(.connected(wrap(peripheral)))
        resumeConnect(key(for: peripheral), result: .success(()))
    }

    func didConnectError(_ peripheral: BZPeripheral, error: Error?) {
        let failure = error.map(BLEError.init) ?? BLEError.disconnected
        emit(.failed(wrap(peripheral), failure))
        resumeConnect(key(for: peripheral), result: .failure(failure))
    }

    func didDisconnected(_ peripheral: BZPeripheral, error: Error?) {
        let id = key(for: peripheral)
        let failure = error.map(BLEError.init)
        emit(.disconnected(wrap(peripheral), failure))
        resumeConnect(id, result: .failure(failure ?? BLEError.disconnected))
        resumeDisconnect(id)
    }

    func didRestored(_ peripheral: BZPeripheral) {
        emit(.restored(wrap(peripheral)))
    }

    func centralDidRestore(_ peripheral: BZPeripheral) {
        let wrapped = wrap(peripheral)
        if let delegate = peripheral.connectStateDelegate as AnyObject? {
            if delegate !== bridge {
                emit(.restored(wrapped))
            }
        } else {
            peripheral.connectStateDelegate = bridge
            emit(.restored(wrapped))
        }
    }

    private func stream<T>(into keyPath: ReferenceWritableKeyPath<BLECentral, [String: AsyncStream<T>.Continuation]>, initial: T? = nil) -> AsyncStream<T> {
        AsyncStream { continuation in
            let id = UUID().uuidString
            self.lock.lock()
            self[keyPath: keyPath][id] = continuation
            self.lock.unlock()
            if let initial = initial {
                continuation.yield(initial)
            }
            let raw = UInt(bitPattern: Unmanaged.passUnretained(self).toOpaque())
            continuation.onTermination = { @Sendable _ in
                guard let pointer = UnsafeRawPointer(bitPattern: raw) else { return }
                let central = Unmanaged<BLECentral>.fromOpaque(pointer).takeUnretainedValue()
                central.lock.lock()
                central[keyPath: keyPath][id] = nil
                central.lock.unlock()
            }
        }
    }

    private func yield<T>(_ value: T, from keyPath: KeyPath<BLECentral, [String: AsyncStream<T>.Continuation]>) {
        lock.lock()
        let continuations = Array(self[keyPath: keyPath].values)
        lock.unlock()
        continuations.forEach { $0.yield(value) }
    }

    private func finish<T>(_ keyPath: ReferenceWritableKeyPath<BLECentral, [String: AsyncStream<T>.Continuation]>) {
        lock.lock()
        let continuations = Array(self[keyPath: keyPath].values)
        self[keyPath: keyPath].removeAll()
        lock.unlock()
        continuations.forEach { $0.finish() }
    }

    private func rememberScan(services: [CBUUID], allowDuplicates: Bool) -> UInt {
        lock.lock()
        scanGeneration &+= 1
        let generation = scanGeneration
        pendingScan = PendingScan(services: services, allowDuplicates: allowDuplicates)
        lock.unlock()
        return generation
    }

    private func startPendingScan(_ generation: UInt) {
        let deliver = {
            guard self.manager.isStatePoweredOn() else { return }
            self.lock.lock()
            guard self.scanGeneration == generation, let pending = self.pendingScan else {
                self.lock.unlock()
                return
            }
            let services = pending.services
            let allowDuplicates = pending.allowDuplicates
            self.lock.unlock()
            self.manager.scanDelegate = self.bridge
            self.manager.startScan(withServices: services, allowDup: allowDuplicates)
        }
        if Thread.isMainThread {
            deliver()
        } else {
            DispatchQueue.main.async(execute: deliver)
        }
    }

    private func key(for peripheral: BZPeripheral) -> String {
        if let uuid = peripheral.uuidString, !uuid.isEmpty {
            return uuid
        }
        return ObjectIdentifier(peripheral).debugDescription
    }

    private func resumeConnect(_ id: String, result: Result<Void, Error>) {
        lock.lock()
        let continuation = connectContinuations.removeValue(forKey: id)
        lock.unlock()
        continuation?.resume(with: result)
    }

    private func resumeDisconnect(_ id: String) {
        lock.lock()
        let continuation = disconnectContinuations.removeValue(forKey: id)
        lock.unlock()
        continuation?.resume()
    }

    private func register(_ peripheral: BLEPeripheral, connected: Bool) {
        guard !peripheral.uuidString.isEmpty else { return }
        if manager.getPeripheral(peripheral.uuidString) != nil {
            return
        }
        track(peripheral)
        let wrapped = wrap(peripheral.peripheral)
        emit(connected ? .retrievedConnected(wrapped) : .retrieved(wrapped))
    }

    private func remember(_ peripheral: BLEPeripheral) {
        guard !peripheral.uuidString.isEmpty else { return }
        lock.lock()
        wrappers[peripheral.uuidString] = peripheral
        lock.unlock()
    }

    private func forget(_ peripheral: BLEPeripheral) {
        guard !peripheral.uuidString.isEmpty else { return }
        lock.lock()
        wrappers.removeValue(forKey: peripheral.uuidString)
        lock.unlock()
    }

    private func cachedWrapper(_ identifier: String) -> BLEPeripheral? {
        lock.lock()
        let cached = wrappers[identifier]
        lock.unlock()
        return cached
    }

    private func wrap(_ peripheral: BZPeripheral) -> BLEPeripheral {
        let id = key(for: peripheral)
        if !peripheral.uuidString.isNilOrEmpty, let cached = cachedWrapper(id) {
            if cached.peripheral !== peripheral, let ble = peripheral.blePeripheral {
                cached.peripheral.updateBLEPeripheral(ble)
            }
            return cached
        }
        let wrapped = BLEPeripheral(peripheral)
        remember(wrapped)
        return wrapped
    }

    private func emit(_ event: BLEConnectionEvent) {
        yield(event, from: \.connectionContinuations)
    }

    private func finishConnections() {
        finish(\.connectionContinuations)
    }
}

@available(iOS 13.0, *)
final class BLECentralBridge: NSObject, BZScanDelegate, BZCentralStateDelegate, BZConnectStateDelegate {
    weak var owner: BLECentral?

    func centralDidUpdate(_ state: CBManagerState) {
        owner?.centralDidUpdate(state)
    }

    func centralDidRestore(_ peripheral: BZPeripheral) {
        owner?.centralDidRestore(peripheral)
    }

    func didScanning(_ peripheral: BZPeripheral, advData: [String: Any]) {
        owner?.didScanning(peripheral, advData: advData)
    }

    func didConnecting(_ peripheral: BZPeripheral) {
        owner?.didConnecting(peripheral)
    }

    func didConnected(_ peripheral: BZPeripheral) {
        owner?.didConnected(peripheral)
    }

    func didConnectError(_ peripheral: BZPeripheral, error: Error?) {
        owner?.didConnectError(peripheral, error: error)
    }

    func didDisconnected(_ peripheral: BZPeripheral, error: Error?) {
        owner?.didDisconnected(peripheral, error: error)
    }

    func didRestored(_ peripheral: BZPeripheral) {
        owner?.didRestored(peripheral)
    }
}

private struct PendingScan {
    var services: [CBUUID]
    var allowDuplicates: Bool
}

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        switch self {
        case .none:
            return true
        case .some(let value):
            return value.isEmpty
        }
    }
}
