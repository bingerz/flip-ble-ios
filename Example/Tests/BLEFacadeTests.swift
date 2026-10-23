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
