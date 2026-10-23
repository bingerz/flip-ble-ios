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

    public init(_ peripheral: BZPeripheral) {
        self.peripheral = peripheral
        self.rssi = peripheral.scannedRSSINumber
        super.init()
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

private func retainedObjectToken(_ object: NSObject) -> UInt {
    UInt(bitPattern: Unmanaged.passRetained(object).toOpaque())
}

private func takeRetainedObject<T: NSObject>(_ token: UInt) -> T {
    Unmanaged<T>.fromOpaque(UnsafeRawPointer(bitPattern: token)!).takeRetainedValue()
}
