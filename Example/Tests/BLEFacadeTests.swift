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

private enum BLEErrorKind: Equatable {
    case disconnected
    case gatt
    case scanFailed
    case invalidOperation
    case underlying
}
