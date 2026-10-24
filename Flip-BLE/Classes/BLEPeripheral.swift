import CoreBluetooth
import Foundation

@available(iOS 13.0, *)
public enum BLEPeripheralPhase {
    case disconnected
    case connecting
    case connected
    case discovering
    case discovered
    case disconnecting

    init(_ state: BZPeripheralState) {
        switch state {
        case .disconnected:
            self = .disconnected
        case .connecting:
            self = .connecting
        case .connected:
            self = .connected
        case .discovering:
            self = .discovering
        case .discovered:
            self = .discovered
        case .disconnecting:
            self = .disconnecting
        @unknown default:
            self = .disconnected
        }
    }
}

@available(iOS 13.0, *)
public final class BLEPeripheral: NSObject {
    public let peripheral: BZPeripheral
    public var rssi: NSNumber?

    private let connectionBridge = BLEPeripheralConnectionBridge()
    private let connectionLock = NSLock()
    private var connectionContinuations: [UUID: AsyncStream<BLEConnectionEvent>.Continuation] = [:]

    public init(_ peripheral: BZPeripheral) {
        self.peripheral = peripheral
        self.rssi = peripheral.scannedRSSINumber
        super.init()
        connectionBridge.owner = self
    }

    public var name: String? {
        peripheral.name
    }

    public var uuidString: String {
        peripheral.uuidString ?? ""
    }

    public var services: [CBService] {
        peripheral.services ?? []
    }

    public var isConnected: Bool {
        peripheral.isConnected
    }

    public var isConnecting: Bool {
        peripheral.isConnecting
    }

    public var phase: BLEPeripheralPhase {
        BLEPeripheralPhase(peripheral.state)
    }

    public func contains(service: CBUUID, characteristic: CBUUID) -> Bool {
        peripheral.isContainCharact(with: service, charact: characteristic)
    }

    public func contains(service: String, characteristic: String) -> Bool {
        peripheral.isContainCharact(with: service, charact: characteristic)
    }

    public func readRSSI() async throws -> NSNumber {
        try await withCheckedThrowingContinuation { continuation in
            let gate = ResumeGate()
            let started = peripheral.readRSSI { value, error in
                gate.run {
                    if let error = error {
                        continuation.resume(throwing: BLEError(error))
                    } else {
                        continuation.resume(returning: value ?? 0)
                    }
                }
            }
            if !started {
                gate.run {
                    continuation.resume(throwing: BLEError.disconnected)
                }
            }
        }
    }

    public func discover(services: [CBUUID]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let gate = ResumeGate()
            let callback: BZPeripheral.DiscoverServiceHandler = { _, error in
                gate.run {
                    if let error = error {
                        continuation.resume(throwing: BLEError(error))
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
            let started = self.peripheral.discoverService(services, callback: callback)
            if !started {
                gate.run {
                    continuation.resume(throwing: BLEError.disconnected)
                }
            }
        }
    }

    public func discoverServices() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let gate = ResumeGate()
            let callback: BZPeripheral.DiscoverHandler = { _, error in
                gate.run {
                    if let error = error {
                        continuation.resume(throwing: BLEError(error))
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
            let started = self.peripheral.discoverServices(callback)
            if !started {
                gate.run {
                    continuation.resume(throwing: BLEError.disconnected)
                }
            }
        }
    }

    public func read(_ characteristic: CBCharacteristic) async throws -> Data {
        try await readValue { callback in
            peripheral.read(withCharact: characteristic, callback: callback)
        }
    }

    public func read(service: CBUUID, characteristic: CBUUID) async throws -> Data {
        try await readValue { callback in
            peripheral.read(with: service, charactUUID: characteristic, callback: callback)
        }
    }

    public func write(_ characteristic: CBCharacteristic, _ value: Data) async throws -> Data {
        try await writeValue(value) { callback in
            peripheral.write(withCharact: characteristic, value: value, callback: callback)
        }
    }

    public func write(service: CBUUID, characteristic: CBUUID, value: Data) async throws -> Data {
        try await writeValue(value) { callback in
            peripheral.write(with: service, charactUUID: characteristic, value: value, callback: callback)
        }
    }

    public func notify(_ characteristic: CBCharacteristic) -> AsyncThrowingStream<Data, Error> {
        subscribe(characteristic, notify: true)
    }

    public func notify(service: CBUUID, characteristic: CBUUID) -> AsyncThrowingStream<Data, Error> {
        subscribe(service: service, characteristic: characteristic, notify: true)
    }

    public func indicate(_ characteristic: CBCharacteristic) -> AsyncThrowingStream<Data, Error> {
        subscribe(characteristic, notify: false)
    }

    public func indicate(service: CBUUID, characteristic: CBUUID) -> AsyncThrowingStream<Data, Error> {
        subscribe(service: service, characteristic: characteristic, notify: false)
    }

    public func connect() -> Bool {
        peripheral.connect()
    }

    public func disconnect() -> Bool {
        peripheral.disconnect()
    }

    public func observeConnection() -> AsyncStream<BLEConnectionEvent>? {
        let manager = BZCentralManager.default()
        if let identifier = peripheral.uuidString, !identifier.isEmpty,
           let existing = manager.getPeripheral(identifier), existing !== peripheral {
            return nil
        }
        guard ownsConnection else { return nil }
        peripheral.connectStateDelegate = connectionBridge
        if let identifier = peripheral.uuidString, !identifier.isEmpty, manager.getPeripheral(identifier) == nil {
            manager.add(peripheral)
        }
        return AsyncStream { continuation in
            let id = UUID()
            self.connectionLock.lock()
            self.connectionContinuations[id] = continuation
            self.connectionLock.unlock()
            let token = retainedObjectToken(self)
            continuation.onTermination = { @Sendable _ in
                let owner: BLEPeripheral = takeRetainedObject(token)
                owner.connectionLock.lock()
                owner.connectionContinuations[id] = nil
                owner.connectionLock.unlock()
            }
        }
    }

    public func detach() {
        if ownsConnection, peripheral.connectStateDelegate != nil {
            peripheral.connectStateDelegate = nil
        }
        let manager = BZCentralManager.default()
        if let identifier = peripheral.uuidString, !identifier.isEmpty, manager.getPeripheral(identifier) === peripheral {
            manager.remove(peripheral)
        }
        finishConnections()
    }

    @discardableResult
    public func adopt(_ discovered: BZPeripheral) -> Bool {
        guard peripheral.connectStateDelegate as AnyObject? === connectionBridge else { return false }
        if let identifier = peripheral.uuidString, !identifier.isEmpty,
           let existing = BZCentralManager.default().getPeripheral(identifier), existing !== peripheral {
            return false
        }
        if let discoveredID = discovered.uuidString, !discoveredID.isEmpty,
           let currentID = peripheral.uuidString, !currentID.isEmpty, discoveredID != currentID {
            return false
        }
        if let replacement = discovered.blePeripheral {
            peripheral.updateBLEPeripheral(replacement)
        }
        peripheral.scannedRSSINumber = discovered.scannedRSSINumber
        rssi = discovered.scannedRSSINumber
        return true
    }

    public func reportRetrieved() {
        emitObserved(.retrieved(self))
    }

    public func reportRetrievedConnected() {
        emitObserved(.retrievedConnected(self))
    }

    public func discoverIfIdle() async throws {
        if peripheral.state == .discovering {
            throw BLEError.invalidOperation("Discovery is already in progress")
        }
        try await discoverServices()
    }

    public func writeCharacteristic(_ characteristic: CBCharacteristic, _ value: Data) async throws -> CBCharacteristic {
        try await yieldedCharacteristic { callback in
            peripheral.write(withCharact: characteristic, value: value, callback: callback)
        }
    }

    public func writeCharacteristic(service: CBUUID, characteristic: CBUUID, value: Data) async throws -> CBCharacteristic {
        try await yieldedCharacteristic { callback in
            peripheral.write(with: service, charactUUID: characteristic, value: value, callback: callback)
        }
    }

    public func setNotify(_ characteristic: CBCharacteristic,
                          state: @escaping BZPeripheral.NotifyHandler,
                          value: @escaping BZPeripheral.NotifyHandler) -> () -> Void {
        subscription(enable: {
            peripheral.setNotifyWithCharact(characteristic, enable: true, stateCallback: state, valueCallback: value)
        }, disable: {
            let ignored: BZPeripheral.NotifyHandler = { _, _ in }
            _ = self.peripheral.setNotifyWithCharact(characteristic, enable: false, stateCallback: ignored, valueCallback: ignored)
        })
    }

    public func setNotify(service: CBUUID,
                          characteristic: CBUUID,
                          state: @escaping BZPeripheral.NotifyHandler,
                          value: @escaping BZPeripheral.NotifyHandler) -> () -> Void {
        subscription(enable: {
            peripheral.setNotifyWith(service, charactUUID: characteristic, enable: true, stateCallback: state, valueCallback: value)
        }, disable: {
            let ignored: BZPeripheral.NotifyHandler = { _, _ in }
            _ = self.peripheral.setNotifyWith(service, charactUUID: characteristic, enable: false, stateCallback: ignored, valueCallback: ignored)
        })
    }

    public func setIndicate(_ characteristic: CBCharacteristic,
                            state: @escaping BZPeripheral.IndicateHandler,
                            value: @escaping BZPeripheral.IndicateHandler) -> () -> Void {
        subscription(enable: {
            peripheral.setIndicateWithCharact(characteristic, enable: true, stateCallback: state, valueCallback: value)
        }, disable: {
            let ignored: BZPeripheral.IndicateHandler = { _, _ in }
            _ = self.peripheral.setIndicateWithCharact(characteristic, enable: false, stateCallback: ignored, valueCallback: ignored)
        })
    }

    public func setIndicate(service: CBUUID,
                            characteristic: CBUUID,
                            state: @escaping BZPeripheral.IndicateHandler,
                            value: @escaping BZPeripheral.IndicateHandler) -> () -> Void {
        subscription(enable: {
            peripheral.setIndicateWith(service, charactUUID: characteristic, enable: true, stateCallback: state, valueCallback: value)
        }, disable: {
            let ignored: BZPeripheral.IndicateHandler = { _, _ in }
            _ = self.peripheral.setIndicateWith(service, charactUUID: characteristic, enable: false, stateCallback: ignored, valueCallback: ignored)
        })
    }

    private var ownsConnection: Bool {
        let delegate = peripheral.connectStateDelegate as AnyObject?
        return delegate == nil || delegate === connectionBridge
    }

    fileprivate func receive(_ event: BLEConnectionEvent) {
        emitObserved(event)
    }

    private func emitObserved(_ event: BLEConnectionEvent) {
        guard peripheral.connectStateDelegate as AnyObject? === connectionBridge else { return }
        connectionLock.lock()
        let continuations = Array(connectionContinuations.values)
        connectionLock.unlock()
        continuations.forEach { $0.yield(event) }
    }

    private func finishConnections() {
        connectionLock.lock()
        let continuations = Array(connectionContinuations.values)
        connectionContinuations.removeAll()
        connectionLock.unlock()
        continuations.forEach { $0.finish() }
    }

    private func yieldedCharacteristic(_ start: (@escaping BZPeripheral.WriteHandler) -> Bool) async throws -> CBCharacteristic {
        try await withCheckedThrowingContinuation { continuation in
            let gate = ResumeGate()
            let started = start { characteristic, error in
                gate.run {
                    if let error = error {
                        continuation.resume(throwing: BLEError(error))
                    } else if let characteristic = characteristic {
                        continuation.resume(returning: characteristic)
                    } else {
                        continuation.resume(throwing: BLEError.invalidOperation("Write returned no characteristic"))
                    }
                }
            }
            if !started {
                gate.run {
                    continuation.resume(throwing: BLEError.disconnected)
                }
            }
        }
    }

    private func subscription(enable: () -> Bool, disable: @escaping () -> Void) -> () -> Void {
        guard enable() else { return {} }
        let cancel = SubscriptionCancel(disable)
        return { cancel.call() }
    }

    private func readValue(_ start: (@escaping BZPeripheral.ReadHandler) -> Bool) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let gate = ResumeGate()
            let started = start { characteristic, error in
                gate.run {
                    if let error = error {
                        continuation.resume(throwing: BLEError(error))
                    } else {
                        continuation.resume(returning: characteristic?.value ?? Data())
                    }
                }
            }
            if !started {
                gate.run {
                    continuation.resume(throwing: BLEError.disconnected)
                }
            }
        }
    }

    private func writeValue(_ value: Data, _ start: (@escaping BZPeripheral.WriteHandler) -> Bool) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let gate = ResumeGate()
            let started = start { _, error in
                gate.run {
                    if let error = error {
                        continuation.resume(throwing: BLEError(error))
                    } else {
                        continuation.resume(returning: value)
                    }
                }
            }
            if !started {
                gate.run {
                    continuation.resume(throwing: BLEError.disconnected)
                }
            }
        }
    }

    private func subscribe(_ characteristic: CBCharacteristic, notify: Bool) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let gate = ResumeGate()
            let fail: (Error) -> Void = { error in
                gate.run { continuation.finish(throwing: error) }
            }
            let started = beginSubscription(notify: notify, state: { _, error in
                if let error = error {
                    fail(BLEError(error))
                }
            }, value: { characteristic, error in
                if let error = error {
                    fail(BLEError(error))
                    return
                }
                continuation.yield(characteristic?.value ?? Data())
            }, startWithCharacteristic: characteristic, service: nil, characteristicUUID: nil)
            if !started {
                fail(BLEError.disconnected)
            }
            let targetToken = retainedObjectToken(peripheral)
            let characteristicToken = retainedObjectToken(characteristic)
            continuation.onTermination = { @Sendable _ in
                DispatchQueue.main.async {
                    let target: BZPeripheral = takeRetainedObject(targetToken)
                    let characteristic: CBCharacteristic = takeRetainedObject(characteristicToken)
                    let state: BZPeripheral.NotifyHandler = { _, _ in }
                    let value: BZPeripheral.NotifyHandler = { _, _ in }
                    if notify {
                        _ = target.setNotifyWithCharact(characteristic, enable: false, stateCallback: state, valueCallback: value)
                    } else {
                        _ = target.setIndicateWithCharact(characteristic, enable: false, stateCallback: state, valueCallback: value)
                    }
                }
            }
        }
    }

    private func subscribe(service: CBUUID, characteristic: CBUUID, notify: Bool) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let gate = ResumeGate()
            let fail: (Error) -> Void = { error in
                gate.run { continuation.finish(throwing: error) }
            }
            let started = beginSubscription(notify: notify, state: { _, error in
                if let error = error {
                    fail(BLEError(error))
                }
            }, value: { updated, error in
                if let error = error {
                    fail(BLEError(error))
                    return
                }
                continuation.yield(updated?.value ?? Data())
            }, startWithCharacteristic: nil, service: service, characteristicUUID: characteristic)
            if !started {
                fail(BLEError.disconnected)
            }
            let targetToken = retainedObjectToken(peripheral)
            let serviceToken = retainedObjectToken(service)
            let characteristicToken = retainedObjectToken(characteristic)
            continuation.onTermination = { @Sendable _ in
                DispatchQueue.main.async {
                    let target: BZPeripheral = takeRetainedObject(targetToken)
                    let service: CBUUID = takeRetainedObject(serviceToken)
                    let characteristic: CBUUID = takeRetainedObject(characteristicToken)
                    let state: BZPeripheral.NotifyHandler = { _, _ in }
                    let value: BZPeripheral.NotifyHandler = { _, _ in }
                    if notify {
                        _ = target.setNotifyWith(service, charactUUID: characteristic, enable: false, stateCallback: state, valueCallback: value)
                    } else {
                        _ = target.setIndicateWith(service, charactUUID: characteristic, enable: false, stateCallback: state, valueCallback: value)
                    }
                }
            }
        }
    }

    private func beginSubscription(notify: Bool,
                                   state: @escaping BZPeripheral.NotifyHandler,
                                   value: @escaping BZPeripheral.NotifyHandler,
                                   startWithCharacteristic: CBCharacteristic?,
                                   service: CBUUID?,
                                   characteristicUUID: CBUUID?) -> Bool {
        if notify {
            if let startWithCharacteristic = startWithCharacteristic {
                return peripheral.setNotifyWithCharact(startWithCharacteristic, enable: true, stateCallback: state, valueCallback: value)
            }
            if let service = service, let characteristicUUID = characteristicUUID {
                return peripheral.setNotifyWith(service, charactUUID: characteristicUUID, enable: true, stateCallback: state, valueCallback: value)
            }
        } else {
            if let startWithCharacteristic = startWithCharacteristic {
                return peripheral.setIndicateWithCharact(startWithCharacteristic, enable: true, stateCallback: state, valueCallback: value)
            }
            if let service = service, let characteristicUUID = characteristicUUID {
                return peripheral.setIndicateWith(service, charactUUID: characteristicUUID, enable: true, stateCallback: state, valueCallback: value)
            }
        }
        return false
    }
}

@available(iOS 13.0, *)
final class BLEPeripheralConnectionBridge: NSObject, BZConnectStateDelegate {
    weak var owner: BLEPeripheral?

    func didConnecting(_ peripheral: BZPeripheral) {
        emit(BLEConnectionEvent.connecting)
    }

    func didRetrieve(_ peripheral: BZPeripheral) {
        emit(BLEConnectionEvent.retrieved)
    }

    func didRetrieveConnected(_ peripheral: BZPeripheral) {
        emit(BLEConnectionEvent.retrievedConnected)
    }

    func didConnected(_ peripheral: BZPeripheral) {
        emit(BLEConnectionEvent.connected)
    }

    func didConnectError(_ peripheral: BZPeripheral, error: Error?) {
        guard let owner = owner else { return }
        owner.receive(.failed(owner, error.map(BLEError.init) ?? .disconnected))
    }

    func didDisconnected(_ peripheral: BZPeripheral, error: Error?) {
        guard let owner = owner else { return }
        owner.receive(.disconnected(owner, error.map(BLEError.init)))
    }

    func didRestored(_ peripheral: BZPeripheral) {
        emit(BLEConnectionEvent.restored)
    }

    private func emit(_ make: (BLEPeripheral) -> BLEConnectionEvent) {
        guard let owner = owner else { return }
        owner.receive(make(owner))
    }
}

private final class SubscriptionCancel {
    private let lock = NSLock()
    private var cancelled = false
    private let body: () -> Void

    init(_ body: @escaping () -> Void) {
        self.body = body
    }

    func call() {
        let run = {
            self.lock.lock()
            let shouldRun = !self.cancelled
            self.cancelled = true
            self.lock.unlock()
            if shouldRun {
                self.body()
            }
        }
        if Thread.isMainThread {
            run()
        } else {
            DispatchQueue.main.async(execute: run)
        }
    }
}

private func retainedObjectToken(_ object: NSObject) -> UInt {
    UInt(bitPattern: Unmanaged.passRetained(object).toOpaque())
}

private func takeRetainedObject<T: NSObject>(_ token: UInt) -> T {
    Unmanaged<T>.fromOpaque(UnsafeRawPointer(bitPattern: token)!).takeRetainedValue()
}
