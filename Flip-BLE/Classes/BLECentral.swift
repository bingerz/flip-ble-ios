import CoreBluetooth
import Foundation

@available(iOS 13.0, *)
public struct BLEAdvertisement {
    public let peripheral: BLEPeripheral
    public let advertisementData: [String: Any]
    public let rssi: NSNumber?
}

@available(iOS 13.0, *)
public final class BLECentral: NSObject, BZScanDelegate, BZCentralStateDelegate, BZConnectStateDelegate {
    public static let shared = BLECentral()

    private let manager = BZCentralManager.default()
    private let lock = NSLock()
    private var scanContinuation: AsyncStream<BLEAdvertisement>.Continuation?
    private var stateContinuation: AsyncStream<CBManagerState>.Continuation?
    private var connectContinuations: [String: CheckedContinuation<Void, Error>] = [:]
    private var disconnectContinuations: [String: CheckedContinuation<Void, Never>] = [:]

    private override init() {
        super.init()
    }

    public func start(restoreIdentifier: String?, showPowerAlert: Bool) {
        manager.centralStateDelegate = self
        manager.scanDelegate = self
        manager.startCentral(withRestoreIdKey: restoreIdentifier, showPowerAlert: showPowerAlert)
    }

    public func destroy() {
        stopScan()
        manager.destroyCentral()
    }

    public var isPoweredOn: Bool {
        manager.isStatePoweredOn()
    }

    public func observeState() -> AsyncStream<CBManagerState> {
        AsyncStream { continuation in
            self.stateContinuation?.finish()
            self.stateContinuation = continuation
        }
    }

    public func scan(services: [CBUUID], allowDuplicates: Bool = false) -> AsyncStream<BLEAdvertisement> {
        let stream = AsyncStream<BLEAdvertisement> { continuation in
            self.scanContinuation?.finish()
            self.scanContinuation = continuation
        }
        manager.scanDelegate = self
        manager.startScan(withServices: services, allowDup: allowDuplicates)
        return stream
    }

    public func stopScan() {
        manager.stopScan()
        scanContinuation?.finish()
        scanContinuation = nil
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
            peripheral.peripheral.connectStateDelegate = self
            manager.add(peripheral.peripheral)
            manager.connect(peripheral.peripheral)
        }
    }

    public func disconnect(_ peripheral: BLEPeripheral) async {
        guard peripheral.isConnected else { return }
        await withCheckedContinuation { continuation in
            let id = key(for: peripheral.peripheral)
            lock.lock()
            disconnectContinuations[id] = continuation
            lock.unlock()
            peripheral.peripheral.connectStateDelegate = self
            manager.cancel(peripheral.peripheral)
        }
    }

    public func retrievePeripherals(identifiers: [String]) -> [BLEPeripheral] {
        (manager.retrievePeripherals(identifiers) ?? []).map { BLEPeripheral($0) }
    }

    public func retrieveConnectedPeripherals(services: [CBUUID]) -> [BLEPeripheral] {
        (manager.retrieveConnectedPeripherals(services) ?? []).map { BLEPeripheral($0) }
    }

    public func centralDidUpdate(_ state: CBManagerState) {
        stateContinuation?.yield(state)
    }

    public func didScanning(_ peripheral: BZPeripheral, advData: [String: Any]) {
        let wrapped = BLEPeripheral(peripheral)
        scanContinuation?.yield(BLEAdvertisement(peripheral: wrapped, advertisementData: advData, rssi: peripheral.scannedRSSINumber))
    }

    public func didConnected(_ peripheral: BZPeripheral) {
        resumeConnect(key(for: peripheral), result: .success(()))
    }

    public func didConnectError(_ peripheral: BZPeripheral, error: Error?) {
        let failure = error.map(BLEError.init) ?? BLEError.disconnected
        resumeConnect(key(for: peripheral), result: .failure(failure))
    }

    public func didDisconnected(_ peripheral: BZPeripheral, error: Error?) {
        let id = key(for: peripheral)
        let failure = error.map(BLEError.init) ?? BLEError.disconnected
        resumeConnect(id, result: .failure(failure))
        resumeDisconnect(id)
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
}
