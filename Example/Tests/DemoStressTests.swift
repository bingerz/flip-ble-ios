import CoreBluetooth
import Flip_BLE
import XCTest
@testable import Flip_BLE_Example

final class DemoStressTests: XCTestCase {

    func testMetricsCountPassesFailuresAndPhaseTime() {
        let metrics = DemoStressMetrics()
        metrics.record(DemoStressCycleResult(
            id: 1,
            identifier: "a",
            passed: true,
            duration: 0.020,
            failedPhase: nil,
            message: nil,
            phaseDurations: [(phase: DemoStressPhase.claim.rawValue, duration: 0.005)]
        ))
        metrics.record(DemoStressCycleResult(
            id: 2,
            identifier: "b",
            passed: false,
            duration: 0.040,
            failedPhase: .signal,
            message: "short",
            phaseDurations: [(phase: DemoStressPhase.signal.rawValue, duration: 0.015)]
        ))

        XCTAssertEqual(metrics.totalCycles, 2)
        XCTAssertEqual(metrics.passedCycles, 1)
        XCTAssertEqual(metrics.failedCycles, 1)
        XCTAssertEqual(metrics.errorDistribution[.signal], 1)
        XCTAssertEqual(metrics.averageCycleDuration, 0.030, accuracy: 0.0001)
        XCTAssertEqual(metrics.phaseTimings[DemoStressPhase.claim.rawValue]?.count, 1)
    }

    func testRepeatedCyclesPassAndLeaveTheTable() {
        let engine = DemoStressEngine()
        engine.config.totalCycles = 30
        engine.config.subscriberCount = 4
        let finished = expectation(description: "stress run finished")
        engine.onFinished = { finished.fulfill() }
        engine.start()
        wait(for: [finished], timeout: 30)

        XCTAssertEqual(engine.metrics.totalCycles, 30)
        XCTAssertEqual(engine.metrics.passedCycles, 30)
        XCTAssertEqual(engine.metrics.failedCycles, 0)
        XCTAssertFalse(engine.isRunning)
    }

    func testStopEndsAfterTheCurrentCycle() {
        let engine = DemoStressEngine()
        engine.config.totalCycles = 40
        let stopped = expectation(description: "first cycle stopped the run")
        engine.onFinished = { XCTFail("a stopped run should not report completion") }
        engine.onCycle = { _ in
            engine.stop()
            stopped.fulfill()
        }
        engine.start()
        wait(for: [stopped], timeout: 5)
        let quiet = expectation(description: "no further cycles")
        quiet.isInverted = true
        wait(for: [quiet], timeout: 0.3)

        XCTAssertEqual(engine.metrics.totalCycles, 1)
        XCTAssertFalse(engine.isRunning)
    }

    func testPauseHoldsTheNextCycle() {
        let engine = DemoStressEngine()
        engine.config.totalCycles = 10
        let paused = expectation(description: "paused after the first cycle")
        let stopped = expectation(description: "stopped after resume")
        engine.onCycle = { result in
            if result.id == 1 {
                engine.pause()
                paused.fulfill()
            }
            if result.id == 2 {
                engine.stop()
                stopped.fulfill()
            }
        }
        engine.start()
        wait(for: [paused], timeout: 5)
        let held = expectation(description: "paused run stays on one cycle")
        held.isInverted = true
        wait(for: [held], timeout: 0.3)
        XCTAssertEqual(engine.metrics.totalCycles, 1)
        XCTAssertTrue(engine.isPaused)

        engine.resume()
        wait(for: [stopped], timeout: 5)
        XCTAssertEqual(engine.metrics.totalCycles, 2)
        XCTAssertFalse(engine.isRunning)
    }

    func testLiveDeviceStaysOffByDefault() {
        let config = DemoStressConfig()
        XCTAssertFalse(config.useLiveDevice)
        XCTAssertEqual(config.deviceName, "")
    }

    func testLiveSelectionPrefersTheStrongestNameMatch() {
        let devices = [
            DemoLiveCandidate(name: "other", identifier: "a", rssi: -40),
            DemoLiveCandidate(name: "Nut Mini", identifier: "b", rssi: -70),
            DemoLiveCandidate(name: "nut", identifier: "c", rssi: -55)
        ]
        XCTAssertEqual(DemoLiveSelection.choose(from: devices, nameFilter: "nut")?.identifier, "c")
        XCTAssertEqual(DemoLiveSelection.choose(from: devices, nameFilter: "")?.identifier, "a")
    }

    func testLiveSelectionKeepsTheOnlyConnectedDeviceWhenTheNameIsEmpty() {
        let chosen = DemoLiveSelection.preferredConnectedIdentifier(
            devices: [(name: "nut", identifier: "abc")],
            nameFilter: " "
        )
        XCTAssertEqual(chosen, "abc")
    }

    func testLiveSelectionDoesNotGuessAmongSeveralConnectedDevices() {
        let chosen = DemoLiveSelection.preferredConnectedIdentifier(
            devices: [(name: "nut", identifier: "a"), (name: "band", identifier: "b")],
            nameFilter: ""
        )
        XCTAssertNil(chosen)
    }

    func testLiveSelectionUsesAUniqueConnectedName() {
        let chosen = DemoLiveSelection.preferredConnectedIdentifier(
            devices: [(name: "nut", identifier: "a"), (name: "band", identifier: "b")],
            nameFilter: "Nut"
        )
        XCTAssertEqual(chosen, "a")
        let ambiguous = DemoLiveSelection.preferredConnectedIdentifier(
            devices: [(name: "nut", identifier: "a"), (name: "nut pro", identifier: "b")],
            nameFilter: "nut"
        )
        XCTAssertNil(ambiguous)
        XCTAssertFalse(DemoLiveSelection.matches(name: "band", filter: "nut"))
    }

    func testLiveReadsKeepOnlyReadableCharacteristics() {
        let targets = DemoLiveReads.readable(from: [
            (serviceUUID: "180F", characteristicUUID: "2A19", properties: [.read, .notify]),
            (serviceUUID: "180A", characteristicUUID: "2A29", properties: .write),
            (serviceUUID: "180A", characteristicUUID: "2A24", properties: .read)
        ])
        XCTAssertEqual(targets.map { $0.characteristicUUID }, ["2A19", "2A24"])
    }
}
