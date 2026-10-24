import CoreBluetooth
import XCTest
import Flip_BLE
@testable import Flip_BLE

final class BLEFacadeTests: XCTestCase {

    func testErrorMapping() {
        XCTAssertEqual(mapped(.disconnected), .disconnected)
        XCTAssertEqual(mapped(.gattError), .gatt)
        XCTAssertEqual(mapped(.scanFail), .scanFailed)
        if case .invalidOperation = BLEError(LegacyBLEError.errorCode(.other, userInfo: nil)) {
        } else {
            XCTFail("Other should map to invalidOperation")
        }
        if case .underlying = BLEError(NSError(domain: "test", code: 42, userInfo: nil)) {
        } else {
            XCTFail("Unknown code should map to underlying")
        }
    }

    func testResumeGateRunsOnce() {
        let gate = ResumeGate()
        var count = 0
        gate.run { count += 1 }
        gate.run { count += 1 }
        XCTAssertEqual(count, 1)
    }

    func testStopScanCanBeCalledTwice() {
        BLECentral.shared.stopScan()
        BLECentral.shared.stopScan()
    }

    func testRetrieveWithoutIdentifierDoesNotTrack() {
        let central = BLECentral.shared
        let before = central.peripherals.count
        central.registerRetrieved(BLEPeripheral(BZPeripheral()))
        central.registerRetrievedConnected(BLEPeripheral(BZPeripheral()))
        XCTAssertEqual(central.peripherals.count, before)
    }

    func testRestoredEventReachesObserver() {
        let exp = expectation(description: "restored")
        let central = BLECentral.shared
        let raw = BZPeripheral()
        let stream = central.observeConnections()
        let task = Task {
            for await event in stream {
                if case .restored(let peripheral) = event, peripheral.peripheral === raw {
                    exp.fulfill()
                }
                return
            }
        }
        central.didRestored(raw)
        wait(for: [exp], timeout: 2)
        task.cancel()
    }

    func testUnknownPeripheralLookupIsNil() {
        XCTAssertNil(BLECentral.shared.peripheral(identifier: "00000000-0000-0000-0000-000000000099"))
    }

    func testAdvertisementFields() {
        let manufacturer = Data([0x01, 0x02])
        let service = CBUUID(string: "180F")
        let data: [String: Any] = [
            CBAdvertisementDataLocalNameKey: "nut",
            CBAdvertisementDataServiceUUIDsKey: [service],
            CBAdvertisementDataManufacturerDataKey: manufacturer,
            CBAdvertisementDataServiceDataKey: [service: Data([0x0A])],
            CBAdvertisementDataSolicitedServiceUUIDsKey: [CBUUID(string: "1803")],
            CBAdvertisementDataIsConnectable: NSNumber(value: true)
        ]
        let advertisement = BLEAdvertisement(
            peripheral: BLEPeripheral(BZPeripheral()),
            advertisementData: data,
            rssi: nil
        )
        XCTAssertEqual(advertisement.localName, "nut")
        XCTAssertEqual(advertisement.serviceUUIDs, [service])
        XCTAssertEqual(advertisement.manufacturerData, manufacturer)
        XCTAssertTrue(advertisement.isConnectable)
        XCTAssertEqual(advertisement.serviceData[service], Data([0x0A]))
        XCTAssertEqual(advertisement.solicitedServiceUUIDs, [CBUUID(string: "1803")])
        XCTAssertEqual(advertisement.advertisementData[CBAdvertisementDataLocalNameKey] as? String, "nut")
    }

    func testEmptyAdvertisementFields() {
        let advertisement = BLEAdvertisement(
            peripheral: BLEPeripheral(BZPeripheral()),
            advertisementData: [:],
            rssi: nil
        )
        XCTAssertNil(advertisement.localName)
        XCTAssertTrue(advertisement.serviceUUIDs.isEmpty)
        XCTAssertNil(advertisement.manufacturerData)
        XCTAssertFalse(advertisement.isConnectable)
        XCTAssertTrue(advertisement.serviceData.isEmpty)
        XCTAssertTrue(advertisement.solicitedServiceUUIDs.isEmpty)
    }

    func testCentralLeavesForeignDelegatesInPlace() {
        let manager = BZCentralManager.default()
        let previousCentral = manager.centralStateDelegate
        let previousScan = manager.scanDelegate
        let previousCentralManager = manager.centralManager
        let foreign = ForeignRadioOwner()
        manager.centralStateDelegate = foreign
        manager.scanDelegate = foreign
        defer {
            manager.centralStateDelegate = previousCentral
            manager.scanDelegate = previousScan
        }

        let central = BLECentral.shared
        let pending = central.pendingScanServiceUUIDs
        XCTAssertFalse(central.start(restoreIdentifier: nil, showPowerAlert: false))
        XCTAssertFalse(central.restart(restoreIdentifier: nil, showPowerAlert: false))
        XCTAssertFalse(central.destroy())
        _ = central.scan(services: [CBUUID(string: "180F")])
        XCTAssertTrue(manager.centralStateDelegate === foreign)
        XCTAssertTrue(manager.scanDelegate === foreign)
        XCTAssertTrue(manager.centralManager === previousCentralManager)
        XCTAssertEqual(central.pendingScanServiceUUIDs, pending)
    }

    func testTrackLeavesForeignConnectDelegate() {
        let identifier = "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
        let raw = IdentifiedPeripheral(identifier)
        let foreign = ForeignConnectOwner()
        raw.connectStateDelegate = foreign
        let wrapped = BLEPeripheral(raw)
        XCTAssertFalse(BLECentral.shared.track(wrapped))
        XCTAssertTrue(raw.connectStateDelegate === foreign)
        XCTAssertNil(BLECentral.shared.peripheral(identifier: identifier))
    }

    func testCentralStateBeforeStart() {
        let central = BLECentral.shared
        XCTAssertFalse(central.isScanning)
        XCTAssertEqual(central.state, BZCentralManager.default().centralManager?.state ?? .unknown)
    }

    func testObserveStateEmitsCurrentStateFirst() {
        let central = BLECentral.shared
        let expected = central.state
        let exp = expectation(description: "current state")
        let stream = central.observeState()
        let task = Task {
            for await state in stream {
                XCTAssertEqual(state, expected)
                exp.fulfill()
                return
            }
        }
        wait(for: [exp], timeout: 2)
        task.cancel()
    }

    func testScanWaitsUntilPoweredOn() {
        let central = BLECentral.shared
        guard !central.isPoweredOn else { return }
        defer { central.stopScan() }
        let battery = CBUUID(string: "180F")
        let info = CBUUID(string: "180A")
        _ = central.scan(services: [battery], allowDuplicates: true)
        XCTAssertFalse(central.isScanning)
        XCTAssertEqual(central.pendingScanServiceUUIDs, [battery])
        XCTAssertTrue(central.pendingScanAllowsDuplicates)
        _ = central.scan(services: [info], allowDuplicates: false)
        XCTAssertEqual(central.pendingScanServiceUUIDs, [info])
        XCTAssertFalse(central.pendingScanAllowsDuplicates)
        central.centralDidUpdate(.poweredOn)
        central.centralDidUpdate(.resetting)
        XCTAssertFalse(central.isScanning)
        XCTAssertEqual(central.pendingScanServiceUUIDs, [info])
    }

    func testSecondConnectionObserverStaysActive() {
        let central = BLECentral.shared
        let raw = BZPeripheral()
        let first = expectation(description: "first connection observer")
        let second = expectation(description: "second connection observer")
        let streamA = central.observeConnections()
        let streamB = central.observeConnections()
        let taskA = Task {
            for await event in streamA {
                if case .restored(let peripheral) = event, peripheral.peripheral === raw {
                    first.fulfill()
                    return
                }
            }
        }
        let taskB = Task {
            for await event in streamB {
                if case .restored(let peripheral) = event, peripheral.peripheral === raw {
                    second.fulfill()
                    return
                }
            }
        }
        central.didRestored(raw)
        wait(for: [first, second], timeout: 2)
        taskA.cancel()
        taskB.cancel()
    }

    func testRepeatedScanReusesPeripheralAndUpdatesRSSI() {
        let central = BLECentral.shared
        let identifier = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
        let firstPeripheral = IdentifiedPeripheral(identifier)
        firstPeripheral.scannedRSSINumber = NSNumber(value: -40)
        let secondPeripheral = IdentifiedPeripheral(identifier)
        secondPeripheral.scannedRSSINumber = NSNumber(value: -55)
        let first = expectation(description: "first advertisement")
        let second = expectation(description: "second advertisement")
        let other = expectation(description: "other scan observer")
        let streamA = central.openScanStream()
        let streamB = central.openScanStream()
        var seen: [BLEPeripheral] = []
        let taskA = Task {
            for await advertisement in streamA {
                seen.append(advertisement.peripheral)
                if seen.count == 1 {
                    first.fulfill()
                }
                if seen.count == 2 {
                    second.fulfill()
                    return
                }
            }
        }
        let taskB = Task {
            for await advertisement in streamB {
                if advertisement.peripheral.uuidString == identifier {
                    other.fulfill()
                    return
                }
            }
        }
        central.didScanning(firstPeripheral, advData: [:])
        central.didScanning(secondPeripheral, advData: [:])
        wait(for: [first, second, other], timeout: 2)
        XCTAssertTrue(seen[0] === seen[1])
        XCTAssertEqual(seen[1].rssi?.intValue, -55)
        XCTAssertEqual(seen[1].peripheral.scannedRSSINumber?.intValue, -55)
        taskA.cancel()
        taskB.cancel()
        central.untrack(seen[0])
        central.stopScan()
    }

    func testTrackedRetrieveReturnsCachedPeripheral() {
        let central = BLECentral.shared
        let identifier = "F81D4FAE-7DEC-11D0-A765-00A0C91E6BF6"
        let tracked = BLEPeripheral(IdentifiedPeripheral(identifier))
        central.registerRetrieved(tracked)
        defer { central.untrack(tracked) }
        let before = central.peripherals.count
        let again = central.presented(IdentifiedPeripheral(identifier))
        let unrelated = central.presented(IdentifiedPeripheral("6BA7B810-9DAD-11D1-80B4-00C04FD430C8"))
        XCTAssertTrue(again === tracked)
        XCTAssertFalse(unrelated === tracked)
        XCTAssertEqual(central.peripherals.count, before)
        XCTAssertNil(central.peripheral(identifier: unrelated.uuidString))
    }

    func testObserveConnectionLeavesForeignDelegate() {
        let identifier = "11111111-2222-3333-4444-555555555555"
        let raw = IdentifiedPeripheral(identifier)
        let foreign = ForeignConnectOwner()
        raw.connectStateDelegate = foreign
        let wrapped = BLEPeripheral(raw)
        XCTAssertNil(wrapped.observeConnection())
        XCTAssertTrue(raw.connectStateDelegate === foreign)
        XCTAssertNil(BZCentralManager.default().getPeripheral(identifier))
    }

    func testObserveConnectionLeavesExistingTableEntry() {
        let identifier = "22222222-3333-4444-5555-666666666666"
        let occupant = IdentifiedPeripheral(identifier)
        let manager = BZCentralManager.default()
        manager.add(occupant)
        defer { manager.remove(occupant) }
        let raw = IdentifiedPeripheral(identifier)
        let wrapped = BLEPeripheral(raw)
        XCTAssertNil(wrapped.observeConnection())
        XCTAssertNil(raw.connectStateDelegate)
        XCTAssertTrue(manager.getPeripheral(identifier) === occupant)
    }

    func testDeviceStreamEmitsConnectingOnce() {
        let identifier = "33333333-4444-5555-6666-777777777777"
        let raw = IdentifiedPeripheral(identifier)
        let wrapped = BLEPeripheral(raw)
        guard let stream = wrapped.observeConnection() else {
            XCTFail("observeConnection failed")
            return
        }
        defer { wrapped.detach() }
        guard let delegate = raw.connectStateDelegate as? NSObject else {
            XCTFail("missing bridge")
            return
        }
        let exp = expectation(description: "connecting")
        var events: [BLEConnectionEvent] = []
        let task = Task {
            for await event in stream {
                events.append(event)
                if events.count == 1 {
                    exp.fulfill()
                }
            }
        }
        let plain = NSSelectorFromString("didConnecting")
        let detailed = NSSelectorFromString("didConnectingPeripheral:")
        if delegate.responds(to: plain) {
            delegate.perform(plain)
        }
        if delegate.responds(to: detailed) {
            delegate.perform(detailed, with: raw)
        }
        wait(for: [exp], timeout: 2)
        let settled = expectation(description: "no second connecting")
        settled.isInverted = true
        wait(for: [settled], timeout: 0.2)
        task.cancel()
        XCTAssertFalse(delegate.responds(to: plain))
        XCTAssertTrue(delegate.responds(to: detailed))
        XCTAssertEqual(events.count, 1)
        if case .connecting(let peripheral) = events[0] {
            XCTAssertTrue(peripheral === wrapped)
        } else {
            XCTFail("expected connecting")
        }
    }

    func testDeviceStreamReceivesRestoreAndReportedRetrieve() {
        let identifier = "44444444-5555-6666-7777-888888888888"
        let raw = IdentifiedPeripheral(identifier)
        let wrapped = BLEPeripheral(raw)
        let untouched = BLEPeripheral(IdentifiedPeripheral("44444444-5555-6666-7777-888888888889"))
        untouched.reportRetrieved()
        untouched.reportRetrievedConnected()
        XCTAssertNil(untouched.peripheral.connectStateDelegate)
        guard let stream = wrapped.observeConnection() else {
            XCTFail("observeConnection failed")
            return
        }
        defer { wrapped.detach() }
        let restored = expectation(description: "restored")
        let retrieved = expectation(description: "retrieved")
        let retrievedConnected = expectation(description: "retrieved connected")
        let task = Task {
            for await event in stream {
                switch event {
                case .restored(let peripheral) where peripheral === wrapped:
                    restored.fulfill()
                case .retrieved(let peripheral) where peripheral === wrapped:
                    retrieved.fulfill()
                case .retrievedConnected(let peripheral) where peripheral === wrapped:
                    retrievedConnected.fulfill()
                default:
                    break
                }
            }
        }
        guard let delegate = raw.connectStateDelegate as? NSObject else {
            XCTFail("missing bridge")
            return
        }
        if delegate.responds(to: NSSelectorFromString("didRestored:")) {
            delegate.perform(NSSelectorFromString("didRestored:"), with: raw)
        }
        wrapped.reportRetrieved()
        wrapped.reportRetrievedConnected()
        wait(for: [restored, retrieved, retrievedConnected], timeout: 2)
        task.cancel()
    }

    func testAdoptCopiesRSSIAndLeavesTemporaryOutOfTable() {
        let identifier = "55555555-6666-7777-8888-999999999999"
        let raw = IdentifiedPeripheral(identifier)
        raw.scannedRSSINumber = NSNumber(value: -20)
        let wrapped = BLEPeripheral(raw)
        guard wrapped.observeConnection() != nil else {
            XCTFail("observeConnection failed")
            return
        }
        defer { wrapped.detach() }
        let discovered = IdentifiedPeripheral(identifier)
        discovered.scannedRSSINumber = NSNumber(value: -63)
        let manager = BZCentralManager.default()
        XCTAssertTrue(wrapped.adopt(discovered))
        XCTAssertTrue(manager.getPeripheral(identifier) === raw)
        XCTAssertFalse(manager.getPeripheral(identifier) === discovered)
        XCTAssertEqual(raw.scannedRSSINumber?.intValue, -63)
        XCTAssertEqual(wrapped.rssi?.intValue, -63)
    }

    func testAdoptFailsWhenTableHasAnotherPeripheral() {
        let identifier = "66666666-7777-8888-9999-AAAAAAAAAAAA"
        let raw = IdentifiedPeripheral(identifier)
        raw.scannedRSSINumber = NSNumber(value: -11)
        let wrapped = BLEPeripheral(raw)
        guard wrapped.observeConnection() != nil else {
            XCTFail("observeConnection failed")
            return
        }
        let manager = BZCentralManager.default()
        manager.remove(raw)
        let other = IdentifiedPeripheral(identifier)
        other.scannedRSSINumber = NSNumber(value: -22)
        manager.add(other)
        defer {
            wrapped.detach()
            manager.remove(other)
        }
        let discovered = IdentifiedPeripheral(identifier)
        discovered.scannedRSSINumber = NSNumber(value: -77)
        XCTAssertFalse(wrapped.adopt(discovered))
        XCTAssertEqual(raw.scannedRSSINumber?.intValue, -11)
        XCTAssertEqual(other.scannedRSSINumber?.intValue, -22)
        XCTAssertTrue(manager.getPeripheral(identifier) === other)
        XCTAssertNil(wrapped.observeConnection())
        XCTAssertNotNil(raw.connectStateDelegate)
        let again = BLEPeripheral(IdentifiedPeripheral(identifier))
        XCTAssertNil(again.observeConnection())
        XCTAssertNil(again.peripheral.connectStateDelegate)
        XCTAssertTrue(manager.getPeripheral(identifier) === other)
    }

    func testDetachClearsDelegateAndTableSeparately() {
        let identifier = "77777777-8888-9999-AAAA-BBBBBBBBBBBB"
        let raw = IdentifiedPeripheral(identifier)
        let wrapped = BLEPeripheral(raw)
        guard wrapped.observeConnection() != nil else {
            XCTFail("observeConnection failed")
            return
        }
        let manager = BZCentralManager.default()
        XCTAssertTrue(manager.getPeripheral(identifier) === raw)
        wrapped.detach()
        XCTAssertNil(raw.connectStateDelegate)
        XCTAssertNil(manager.getPeripheral(identifier))

        guard wrapped.observeConnection() != nil else {
            XCTFail("observeConnection failed")
            return
        }
        manager.remove(raw)
        let other = IdentifiedPeripheral("77777777-8888-9999-AAAA-BBBBBBBBBBBC")
        manager.add(other)
        defer { manager.remove(other) }
        wrapped.detach()
        XCTAssertNil(raw.connectStateDelegate)
        XCTAssertTrue(manager.getPeripheral(other.uuidString ?? "") === other)
    }

    func testDiscoverIfIdleDistinguishesDiscoveringFromDisconnected() {
        let discovering = FixedStatePeripheral()
        discovering.fixedState = .discovering
        let discoveringWrapped = BLEPeripheral(discovering)
        let discoveringExp = expectation(description: "discovering rejected")
        Task {
            do {
                try await discoveringWrapped.discoverIfIdle()
                XCTFail("discovering should be rejected")
            } catch let error as BLEError {
                if case .invalidOperation = error {
                    discoveringExp.fulfill()
                } else {
                    XCTFail("unexpected \(error)")
                }
            } catch {
                XCTFail("unexpected \(error)")
            }
        }

        let disconnected = FixedStatePeripheral()
        disconnected.fixedState = .disconnected
        let disconnectedWrapped = BLEPeripheral(disconnected)
        let disconnectedExp = expectation(description: "disconnected")
        Task {
            do {
                try await disconnectedWrapped.discoverIfIdle()
                XCTFail("disconnected should fail")
            } catch let error as BLEError {
                if case .disconnected = error {
                    disconnectedExp.fulfill()
                } else {
                    XCTFail("unexpected \(error)")
                }
            } catch {
                XCTFail("unexpected \(error)")
            }
        }
        wait(for: [discoveringExp, disconnectedExp], timeout: 2)
    }

    func testUnidentifiedPeripheralPhaseIsDisconnected() {
        let peripheral = BLEPeripheral(BZPeripheral())
        XCTAssertEqual(peripheral.uuidString, "")
        XCTAssertEqual(peripheral.phase, .disconnected)
        XCTAssertFalse(peripheral.isConnecting)
        XCTAssertFalse(peripheral.contains(service: CBUUID(string: "180F"), characteristic: CBUUID(string: "2A19")))
        XCTAssertFalse(peripheral.contains(service: "180F", characteristic: "2A19"))
    }

    private func mapped(_ code: BZBLEErrorCode) -> BLEErrorKind {
        switch BLEError(LegacyBLEError.errorCode(code, userInfo: nil)) {
        case .disconnected:
            return .disconnected
        case .gatt:
            return .gatt
        case .scanFailed:
            return .scanFailed
        case .invalidOperation:
            return .invalidOperation
        case .underlying:
            return .underlying
        }
    }

    func testRestoredPeripheralStaysClaimable() {
        let raw = IdentifiedPeripheral(UUID().uuidString)
        BLECentral.shared.centralDidRestore(raw)
        XCTAssertNil(raw.connectStateDelegate)
        let device = BLEPeripheral(raw)
        XCTAssertNotNil(device.observeConnection())
        device.detach()
        XCTAssertNil(raw.connectStateDelegate)
    }
}

private final class ForeignRadioOwner: NSObject, BZCentralStateDelegate, BZScanDelegate {
    func centralDidUpdate(_ state: CBManagerState) {}

    func didScanning(_ peripheral: BZPeripheral, advData: [String: Any]) {}
}

private final class ForeignConnectOwner: NSObject, BZConnectStateDelegate {}

private final class FixedStatePeripheral: BZPeripheral {
    var fixedState: BZPeripheralState = .disconnected

    override var state: BZPeripheralState {
        fixedState
    }
}

private final class IdentifiedPeripheral: BZPeripheral {
    private let identifier: String

    init(_ identifier: String) {
        self.identifier = identifier
        super.init()
    }

    override var uuidString: String? {
        identifier
    }
}

private enum BLEErrorKind: Equatable {
    case disconnected
    case gatt
    case scanFailed
    case invalidOperation
    case underlying
}
