import CoreBluetooth
import XCTest
@testable import Flip_BLE_Example

final class DemoLogicTests: XCTestCase {

    func testCommaTokensTrimAndDropEmpty() {
        XCTAssertEqual(DemoScanRules.commaTokens(" Nut , , FE2C "), ["Nut", "FE2C"])
        XCTAssertEqual(DemoScanRules.commaTokens("   "), [])
    }

    func testEmptyNameFilterAllowsAnyName() {
        XCTAssertTrue(DemoScanRules.passesFilters(name: "Anything", identifier: "ABC", nameFilter: "", identifierFilter: ""))
        XCTAssertTrue(DemoScanRules.passesFilters(name: "Anything", identifier: "ABC", nameFilter: "  ,  ", identifierFilter: ""))
    }

    func testNameAndIdentifierMustBothMatchIgnoringCase() {
        XCTAssertTrue(DemoScanRules.passesFilters(name: "nut", identifier: "AbC-1", nameFilter: "Nut, Other", identifierFilter: "abc-1"))
        XCTAssertFalse(DemoScanRules.passesFilters(name: "nut", identifier: "ABC", nameFilter: "Other", identifierFilter: ""))
        XCTAssertFalse(DemoScanRules.passesFilters(name: "nut", identifier: "ABC", nameFilter: "nut", identifierFilter: "other-id"))
    }

    /// Scanned rows are dropped when Name/ID filters tighten; empty filters keep everything.
    func testTighteningNameFilterWouldDropPreviouslyVisibleScannedNames() {
        XCTAssertTrue(DemoScanRules.passesFilters(name: "Alpha", identifier: "1", nameFilter: "", identifierFilter: ""))
        XCTAssertFalse(DemoScanRules.passesFilters(name: "Alpha", identifier: "1", nameFilter: "Beta", identifierFilter: ""))
        XCTAssertTrue(DemoScanRules.passesFilters(name: "Beta", identifier: "2", nameFilter: "Beta", identifierFilter: ""))
    }

    func testServiceUUIDParsingAndDefaults() {
        XCTAssertNil(DemoScanRules.parseServiceUUID("12"))
        XCTAssertNil(DemoScanRules.parseServiceUUID("zzzz"))
        XCTAssertEqual(DemoScanRules.parseServiceUUID("1803")?.uuidString, "1803")
        XCTAssertNotNil(DemoScanRules.parseServiceUUID("0900ABCD"))
        let full = "00112233-4455-6677-8899-AABBCCDDEEFF"
        XCTAssertNotNil(DemoScanRules.parseServiceUUID(full))

        let defaults = DemoScanRules.serviceUUIDs(from: "").map(\.uuidString)
        XCTAssertEqual(defaults, DemoScanRules.defaultServiceUUIDStrings)

        let mixed = DemoScanRules.serviceUUIDs(from: "1803, not-a-uuid").map(\.uuidString)
        XCTAssertEqual(mixed, ["1803"])
    }

    func testHexRoundTripAndRejection() {
        XCTAssertEqual(DemoHex.string(from: Data()), "empty")
        XCTAssertEqual(DemoHex.string(from: Data([0x0A, 0x1B])), "0A 1B")
        XCTAssertEqual(DemoHex.data(from: "0a 1b"), Data([0x0A, 0x1B]))
        XCTAssertEqual(DemoHex.data(from: "0x0A0x1B"), Data([0x0A, 0x1B]))
        XCTAssertNil(DemoHex.data(from: ""))
        XCTAssertNil(DemoHex.data(from: "0A1"))
        XCTAssertNil(DemoHex.data(from: "0A1G"))
    }

    func testInvalidUUIDTokensAndDefaults() {
        XCTAssertEqual(DemoScanRules.invalidUUIDTokens(from: "1803, zz, 12"), ["zz", "12"])
        XCTAssertTrue(DemoScanRules.usesDefaultServiceUUIDs(from: "zz"))
        XCTAssertFalse(DemoScanRules.usesDefaultServiceUUIDs(from: "1803, zz"))
    }

    func testAdvertisementSummaryLines() {
        let adv: [String: Any] = [
            CBAdvertisementDataServiceDataKey: [CBUUID(string: "FEAA"): Data([0x01, 0x02])],
            CBAdvertisementDataManufacturerDataKey: Data([0x4C, 0x00, 0x10, 0x05]),
            CBAdvertisementDataTxPowerLevelKey: NSNumber(value: -10),
            CBAdvertisementDataIsConnectable: NSNumber(value: true)
        ]
        let lines = DemoAdvertisementSummary.lines(from: adv)
        XCTAssertTrue(lines.contains("Service Data FEAA: 01 02"))
        XCTAssertTrue(lines.contains("Manufacturer 004C: 10 05"))
        XCTAssertTrue(lines.contains("Tx Power: -10 dBm"))
        XCTAssertTrue(lines.contains("Connectable"))
        XCTAssertEqual(DemoAdvertisementSummary.lines(from: [:]), [])
    }

    func testConsoleStoreKeyAndPersistence() {
        let readKey = DemoConsoleStore.key(peripheralID: "P1", characteristicUUID: "C1", action: .read)
        let notifyKey = DemoConsoleStore.key(peripheralID: "P1", characteristicUUID: "C1", action: .notify)
        XCTAssertNotEqual(readKey, notifyKey)
        XCTAssertEqual(readKey, "P1|C1|Read")

        let store = DemoConsoleStore.shared
        store.removeAll()
        store.save(text: "Read 01\n", isOn: true, for: notifyKey)
        XCTAssertEqual(store.entry(for: notifyKey).text, "Read 01\n")
        XCTAssertTrue(store.entry(for: notifyKey).isOn)
        store.clear(for: notifyKey)
        XCTAssertEqual(store.entry(for: notifyKey).text, "")
        XCTAssertFalse(store.entry(for: notifyKey).isOn)
        store.removeAll()
    }

    func testGATTActionsFollowProperties() {
        let all: CBCharacteristicProperties = [.read, .write, .writeWithoutResponse, .notify, .indicate]
        XCTAssertEqual(DemoGATTAction.actions(for: all).map(\.title), ["Read", "Write", "Write No Response", "Notify", "Indicate"])
        XCTAssertEqual(DemoGATTAction.actions(for: CBCharacteristicProperties()), [])
        XCTAssertEqual(DemoGATTAction.summary(for: CBCharacteristicProperties()), "No properties")
        XCTAssertEqual(DemoGATTAction.summary(for: .notify), "Notify")
        XCTAssertEqual(DemoGATTAction.actions(for: .notify).map(\.badgeTitle), ["NOTIFY"])
    }

    func testSignalLevelBands() {
        XCTAssertEqual(DemoSignal.level(for: -48), 4)
        XCTAssertEqual(DemoSignal.level(for: -60), 4)
        XCTAssertEqual(DemoSignal.level(for: -68), 3)
        XCTAssertEqual(DemoSignal.level(for: -76), 2)
        XCTAssertEqual(DemoSignal.level(for: -90), 1)
    }

    func testAdvertisementChipsStayShort() {
        let adv: [String: Any] = [
            CBAdvertisementDataServiceDataKey: [CBUUID(string: "FE2C"): Data([0x01])],
            CBAdvertisementDataTxPowerLevelKey: NSNumber(value: -11),
            CBAdvertisementDataIsConnectable: NSNumber(value: true)
        ]
        XCTAssertEqual(DemoAdvertisementSummary.chips(from: adv), ["TX: -11 dBm", "Connectable", "FE2C"])
        XCTAssertEqual(DemoAdvertisementSummary.chips(from: [:]), [])
    }
}
