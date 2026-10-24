import CoreBluetooth
import XCTest
@testable import Flip_BLE

/// Repeated in-memory operations. These tests do not connect, discover over the radio, read, write, or notify.
final class BLEStabilityTests: XCTestCase {
    private let manager = BZCentralManager.default()

    func testObserveDetachCyclesLeaveTheTableEmpty() {
        let before = BZMultiplePeripheralController.sharedInstance.getPeripherals().count
        for _ in 0..<200 {
            let identifier = UUID().uuidString
            let raw = StablePeripheral(identifier)
            let wrapped = BLEPeripheral(raw)
            XCTAssertNotNil(wrapped.observeConnection())
            XCTAssertTrue(manager.getPeripheral(identifier) === raw)
            wrapped.detach()
            XCTAssertNil(raw.connectStateDelegate)
            XCTAssertNil(manager.getPeripheral(identifier))
        }
        XCTAssertEqual(BZMultiplePeripheralController.sharedInstance.getPeripherals().count, before)
    }

    func testDetachAfterSystemRemovalDoesNotTouchNeighbors() {
        let neighborID = UUID().uuidString
        let neighbor = StablePeripheral(neighborID)
        manager.add(neighbor)
        defer { manager.remove(neighbor) }

        for _ in 0..<80 {
            let identifier = UUID().uuidString
            let raw = StablePeripheral(identifier)
            let wrapped = BLEPeripheral(raw)
            XCTAssertNotNil(wrapped.observeConnection())
            manager.remove(raw)
            wrapped.detach()
            XCTAssertNil(raw.connectStateDelegate)
            XCTAssertNil(manager.getPeripheral(identifier))
            XCTAssertTrue(manager.getPeripheral(neighborID) === neighbor)
        }
    }

    func testManySubscribersReceiveEverySignalOnce() {
        let identifier = UUID().uuidString
        let raw = StablePeripheral(identifier)
        let wrapped = BLEPeripheral(raw)
        let subscribers = 24
        let signals = 40
        var streams: [AsyncStream<BLEConnectionEvent>] = []
        for _ in 0..<subscribers {
            guard let stream = wrapped.observeConnection() else {
                XCTFail("observeConnection failed")
                wrapped.detach()
                return
            }
            streams.append(stream)
        }
        defer { wrapped.detach() }

        let finished = expectation(description: "subscribers received the burst")
        finished.expectedFulfillmentCount = subscribers
        let counts = LockedCounts(subscribers)
        for index in 0..<subscribers {
            let stream = streams[index]
            Task {
                for await event in stream {
                    guard case .connecting = event else { continue }
                    if counts.increment(index) == signals {
                        finished.fulfill()
                    }
                }
            }
        }

        for _ in 0..<signals {
            deliver("didConnecting", to: raw)
            deliver("didConnectingPeripheral:", to: raw, object: raw)
        }
        wait(for: [finished], timeout: 5)
        XCTAssertEqual(counts.values, Array(repeating: signals, count: subscribers))
        XCTAssertTrue(manager.getPeripheral(identifier) === raw)
    }

    func testDetachEndsEverySubscriber() {
        let raw = StablePeripheral(UUID().uuidString)
        let wrapped = BLEPeripheral(raw)
        let subscribers = 30
        var streams: [AsyncStream<BLEConnectionEvent>] = []
        for _ in 0..<subscribers {
            guard let stream = wrapped.observeConnection() else {
                XCTFail("observeConnection failed")
                wrapped.detach()
                return
            }
            streams.append(stream)
        }
        let ended = expectation(description: "subscribers ended")
        ended.expectedFulfillmentCount = subscribers
        for stream in streams {
            Task {
                for await _ in stream {}
                ended.fulfill()
            }
        }
        wrapped.detach()
        wait(for: [ended], timeout: 5)
        XCTAssertNil(raw.connectStateDelegate)
        XCTAssertNil(manager.getPeripheral(raw.uuidString ?? ""))
    }

    func testForeignDelegateSurvivesRepeatedClaims() {
        let raw = StablePeripheral(UUID().uuidString)
        let foreign = ForeignConnectOwner()
        raw.connectStateDelegate = foreign
        let wrapped = BLEPeripheral(raw)
        for index in 0..<120 {
            XCTAssertNil(wrapped.observeConnection())
            let discovered = StablePeripheral(raw.uuidString ?? "")
            discovered.scannedRSSINumber = NSNumber(value: index)
            XCTAssertFalse(wrapped.adopt(discovered))
            wrapped.reportRetrieved()
            wrapped.reportRetrievedConnected()
            wrapped.detach()
            XCTAssertTrue(raw.connectStateDelegate === foreign)
            XCTAssertNil(raw.scannedRSSINumber)
            XCTAssertNil(manager.getPeripheral(raw.uuidString ?? ""))
        }
    }

    func testOccupiedUUIDRejectsRepeatedClaims() {
        let identifier = UUID().uuidString
        let occupant = StablePeripheral(identifier)
        occupant.scannedRSSINumber = NSNumber(value: -5)
        manager.add(occupant)
        defer { manager.remove(occupant) }
        let wrapped = BLEPeripheral(StablePeripheral(identifier))

        for index in 0..<120 {
            XCTAssertNil(wrapped.observeConnection())
            let discovered = StablePeripheral(identifier)
            discovered.scannedRSSINumber = NSNumber(value: -100 - index)
            XCTAssertFalse(wrapped.adopt(discovered))
            wrapped.detach()
            XCTAssertNil(wrapped.peripheral.connectStateDelegate)
            XCTAssertTrue(manager.getPeripheral(identifier) === occupant)
            XCTAssertEqual(occupant.scannedRSSINumber?.intValue, -5)
        }
    }

    func testAdoptRSSITracksTheLatestAdvertisement() {
        let identifier = UUID().uuidString
        let raw = StablePeripheral(identifier)
        let wrapped = BLEPeripheral(raw)
        guard wrapped.observeConnection() != nil else {
            XCTFail("observeConnection failed")
            return
        }
        defer { wrapped.detach() }
        let delegate = raw.connectStateDelegate
        for index in 0..<150 {
            let discovered = StablePeripheral(identifier)
            discovered.scannedRSSINumber = NSNumber(value: -30 - index)
            XCTAssertTrue(wrapped.adopt(discovered))
            XCTAssertTrue(manager.getPeripheral(identifier) === raw)
            XCTAssertFalse(manager.getPeripheral(identifier) === discovered)
            XCTAssertTrue(raw.connectStateDelegate === delegate)
            XCTAssertEqual(raw.scannedRSSINumber?.intValue, -30 - index)
            XCTAssertEqual(wrapped.rssi?.intValue, -30 - index)
        }
    }

    func testCentralTrackCannotReplaceDeviceBridge() {
        let raw = StablePeripheral(UUID().uuidString)
        let wrapped = BLEPeripheral(raw)
        guard wrapped.observeConnection() != nil else {
            XCTFail("observeConnection failed")
            return
        }
        defer { wrapped.detach() }
        let delegate = raw.connectStateDelegate
        let central = BLECentral.shared
        for _ in 0..<80 {
            XCTAssertFalse(central.track(wrapped))
            XCTAssertTrue(raw.connectStateDelegate === delegate)
        }
    }

    func testTrackUntrackChurnRestoresTheTable() {
        let central = BLECentral.shared
        let before = central.peripherals.count
        for _ in 0..<100 {
            let wrapped = BLEPeripheral(StablePeripheral(UUID().uuidString))
            XCTAssertTrue(central.track(wrapped))
            central.untrack(wrapped)
            XCTAssertNil(wrapped.peripheral.connectStateDelegate)
            XCTAssertNil(manager.getPeripheral(wrapped.uuidString))
        }
        XCTAssertEqual(central.peripherals.count, before)
    }

    func testScanObserversStayOnOnePeripheral() {
        let central = BLECentral.shared
        let identifier = UUID().uuidString
        let updates = 50
        let observers = 6
        var streams: [AsyncStream<BLEAdvertisement>] = []
        for _ in 0..<observers {
            streams.append(central.openScanStream())
        }
        var tracked: BLEPeripheral?
        defer {
            if let tracked = tracked {
                central.untrack(tracked)
            }
            central.stopScan()
        }
        let finished = expectation(description: "scan observers")
        finished.expectedFulfillmentCount = observers
        let seen = LockedPeripheralLists(observers)
        for index in 0..<observers {
            let stream = streams[index]
            Task {
                for await advertisement in stream where advertisement.peripheral.uuidString == identifier {
                    seen.append(advertisement.peripheral, at: index)
                    if seen.count(at: index) == updates {
                        finished.fulfill()
                    }
                }
            }
        }
        for index in 0..<updates {
            let raw = StablePeripheral(identifier)
            raw.scannedRSSINumber = NSNumber(value: -20 - index)
            central.didScanning(raw, advData: [:])
        }
        wait(for: [finished], timeout: 5)
        for index in 0..<observers {
            let peripherals = seen.peripherals(at: index)
            XCTAssertEqual(peripherals.count, updates)
            XCTAssertTrue(peripherals.allSatisfy { $0 === peripherals[0] })
            XCTAssertEqual(peripherals[0].rssi?.intValue, -20 - (updates - 1))
            tracked = peripherals[0]
        }
        XCTAssertEqual(tracked?.peripheral.scannedRSSINumber?.intValue, -20 - (updates - 1))
    }

    func testDiscoverIfIdleStaysDistinctUnderRepetition() {
        let discovering = FixedStatePeripheral()
        discovering.fixedState = .discovering
        let discoveringWrapped = BLEPeripheral(discovering)
        let disconnected = FixedStatePeripheral()
        let disconnectedWrapped = BLEPeripheral(disconnected)
        let exp = expectation(description: "discover stress")
        let task = Task {
            for _ in 0..<80 {
                do {
                    try await discoveringWrapped.discoverIfIdle()
                    XCTFail("discovering should be rejected")
                    return
                } catch let error as BLEError {
                    guard case .invalidOperation = error else {
                        XCTFail("unexpected \(error)")
                        return
                    }
                }
                do {
                    try await disconnectedWrapped.discoverIfIdle()
                    XCTFail("disconnected should fail")
                    return
                } catch let error as BLEError {
                    guard case .disconnected = error else {
                        XCTFail("unexpected \(error)")
                        return
                    }
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
        task.cancel()
    }

    func testStateObserversAndStopScanStayStable() {
        let central = BLECentral.shared
        let subscribers = 20
        let expected = central.state
        let exp = expectation(description: "state observers")
        exp.expectedFulfillmentCount = subscribers
        var tasks: [Task<Void, Never>] = []
        for _ in 0..<subscribers {
            let stream = central.observeState()
            tasks.append(Task {
                for await state in stream {
                    XCTAssertEqual(state, expected)
                    exp.fulfill()
                    return
                }
            })
        }
        wait(for: [exp], timeout: 5)
        tasks.forEach { $0.cancel() }
        for _ in 0..<50 {
            central.stopScan()
        }
        XCTAssertFalse(central.isScanning)
    }

    private func deliver(_ selector: String, to raw: BZPeripheral, object: Any? = nil) {
        guard let delegate = raw.connectStateDelegate as? NSObject else {
            XCTFail("missing bridge")
            return
        }
        let method = NSSelectorFromString(selector)
        guard delegate.responds(to: method) else { return }
        if let object = object {
            delegate.perform(method, with: object)
        } else {
            delegate.perform(method)
        }
    }
}

private final class LockedCounts {
    private let lock = NSLock()
    private var storage: [Int]

    init(_ count: Int) {
        storage = Array(repeating: 0, count: count)
    }

    func increment(_ index: Int) -> Int {
        lock.lock()
        storage[index] += 1
        let value = storage[index]
        lock.unlock()
        return value
    }

    var values: [Int] {
        lock.lock()
        let copy = storage
        lock.unlock()
        return copy
    }
}

private final class LockedPeripheralLists {
    private let lock = NSLock()
    private var storage: [[BLEPeripheral]]

    init(_ count: Int) {
        storage = Array(repeating: [], count: count)
    }

    func append(_ peripheral: BLEPeripheral, at index: Int) {
        lock.lock()
        storage[index].append(peripheral)
        lock.unlock()
    }

    func count(at index: Int) -> Int {
        lock.lock()
        let value = storage[index].count
        lock.unlock()
        return value
    }

    func peripherals(at index: Int) -> [BLEPeripheral] {
        lock.lock()
        let copy = storage[index]
        lock.unlock()
        return copy
    }
}

private final class ForeignConnectOwner: NSObject, BZConnectStateDelegate {}

private final class StablePeripheral: BZPeripheral {
    private let identifier: String

    init(_ identifier: String) {
        self.identifier = identifier
        super.init()
    }

    override var uuidString: String? {
        identifier
    }
}

private final class FixedStatePeripheral: BZPeripheral {
    var fixedState: BZPeripheralState = .disconnected

    override var state: BZPeripheralState {
        fixedState
    }
}
