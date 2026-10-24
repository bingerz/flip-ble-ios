import CoreBluetooth
import Darwin
import Flip_BLE
import Foundation

/// One step of a repeated session. The names match the order the engine runs them.
enum DemoStressPhase: String, CaseIterable {
    case claim = "Claim"
    case signal = "Signal"
    case adopt = "Adopt"
    case occupy = "Occupy"
    case scan = "Scan"
    case connect = "Connect"
    case discover = "Discover"
    case read = "Read"
    case rssi = "RSSI"
    case disconnect = "Disconnect"
    case release = "Release"
}

struct DemoLiveCandidate {
    var name: String
    var identifier: String
    var rssi: Int
}

enum DemoLiveReads {
    static func readable(
        from characteristics: [(serviceUUID: String, characteristicUUID: String, properties: CBCharacteristicProperties)]
    ) -> [(serviceUUID: String, characteristicUUID: String)] {
        characteristics.compactMap { item in
            guard item.properties.contains(.read) else { return nil }
            return (serviceUUID: item.serviceUUID, characteristicUUID: item.characteristicUUID)
        }
    }
}

enum DemoLiveSelection {
    static func normalized(_ filter: String) -> String {
        filter.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func matches(name: String, filter: String) -> Bool {
        let needle = normalized(filter)
        if needle.isEmpty { return true }
        return name.range(of: needle, options: .caseInsensitive) != nil
    }

    /// Picks the strongest advertiser whose name contains the filter.
    static func choose(from candidates: [DemoLiveCandidate], nameFilter: String) -> DemoLiveCandidate? {
        candidates
            .filter { matches(name: $0.name, filter: nameFilter) }
            .max { $0.rssi < $1.rssi }
    }

    /// Uses a connected device only when the filter leaves exactly one match.
    static func preferredConnectedIdentifier(
        devices: [(name: String, identifier: String)],
        nameFilter: String
    ) -> String? {
        let matches = devices.filter { self.matches(name: $0.name, filter: nameFilter) }
        guard matches.count == 1 else { return nil }
        return matches[0].identifier
    }
}

struct DemoStressConfig {
    var totalCycles: Int = 200
    var subscriberCount: Int = 4
    var useLiveDevice = false
    var deviceName = ""

    static let `default` = DemoStressConfig()

    var clampedCycles: Int {
        min(1000, max(1, totalCycles))
    }

    var clampedSubscribers: Int {
        min(8, max(1, subscriberCount))
    }
}

struct DemoStressCycleResult {
    let id: Int
    let identifier: String
    let passed: Bool
    let duration: TimeInterval
    let failedPhase: DemoStressPhase?
    let message: String?
    let phaseDurations: [(phase: String, duration: TimeInterval)]
}

struct DemoStressPhaseTiming {
    var totalTime: TimeInterval = 0
    var count: Int = 0
    var minDuration: TimeInterval = .greatestFiniteMagnitude
    var maxDuration: TimeInterval = 0

    var averageDuration: TimeInterval {
        guard count > 0 else { return 0 }
        return totalTime / Double(count)
    }

    mutating func record(_ duration: TimeInterval) {
        totalTime += duration
        count += 1
        if duration < minDuration { minDuration = duration }
        if duration > maxDuration { maxDuration = duration }
    }
}

final class DemoStressMetrics {
    var totalCycles: Int = 0
    var passedCycles: Int = 0
    var failedCycles: Int = 0
    private var cycleDurations: [TimeInterval] = []
    var phaseTimings: [String: DemoStressPhaseTiming] = [:]
    var errorDistribution: [DemoStressPhase: Int] = [:]
    private(set) var memorySnapshots: [(cycle: Int, mb: Double)] = []
    var baselineMemoryMB: Double = 0

    var averageCycleDuration: TimeInterval {
        guard !cycleDurations.isEmpty else { return 0 }
        return cycleDurations.reduce(0, +) / Double(cycleDurations.count)
    }

    var minCycleDuration: TimeInterval {
        cycleDurations.min() ?? 0
    }

    var maxCycleDuration: TimeInterval {
        cycleDurations.max() ?? 0
    }

    var latestMemoryMB: Double {
        memorySnapshots.last?.mb ?? Self.currentMemoryMB()
    }

    var memoryDeltaMB: Double {
        latestMemoryMB - baselineMemoryMB
    }

    func reset() {
        totalCycles = 0
        passedCycles = 0
        failedCycles = 0
        cycleDurations.removeAll()
        phaseTimings.removeAll()
        errorDistribution.removeAll()
        memorySnapshots.removeAll()
        baselineMemoryMB = 0
    }

    func record(_ result: DemoStressCycleResult) {
        totalCycles += 1
        cycleDurations.append(result.duration)
        if result.passed {
            passedCycles += 1
        } else {
            failedCycles += 1
            if let phase = result.failedPhase {
                errorDistribution[phase, default: 0] += 1
            }
        }
        for sample in result.phaseDurations {
            var timing = phaseTimings[sample.phase] ?? DemoStressPhaseTiming()
            timing.record(sample.duration)
            phaseTimings[sample.phase] = timing
        }
    }

    func snapshotMemory(cycle: Int) {
        memorySnapshots.append((cycle: cycle, mb: Self.currentMemoryMB()))
        if memorySnapshots.count > 200 {
            memorySnapshots.removeFirst(memorySnapshots.count - 200)
        }
    }

    static func currentMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / (1024 * 1024)
    }
}

/// Repeats one session many times and records where it fails.
/// The default path stays in memory. A live cycle runs only when `useLiveDevice` is on.
final class DemoStressEngine {
    var config = DemoStressConfig.default
    let metrics = DemoStressMetrics()
    var onCycle: ((DemoStressCycleResult) -> Void)?
    var onFinished: (() -> Void)?

    private var runTask: Task<Void, Never>?
    private var runGeneration = 0
    private var pinnedLiveIdentifier: String?
    private(set) var isPaused = false
    private(set) var isRunning = false

    func start() {
        runGeneration += 1
        isPaused = false
        isRunning = true
        pinnedLiveIdentifier = nil
        config.totalCycles = config.clampedCycles
        config.subscriberCount = config.clampedSubscribers
        metrics.reset()
        metrics.baselineMemoryMB = DemoStressMetrics.currentMemoryMB()
        let generation = runGeneration
        runTask?.cancel()
        runTask = Task { @MainActor [weak self] in
            await self?.executeAllCycles(generation: generation)
        }
    }

    func stop() {
        runGeneration += 1
        isPaused = false
        isRunning = false
        runTask?.cancel()
        runTask = nil
        if config.useLiveDevice {
            BLECentral.shared.stopScan()
        }
    }

    func pause() {
        guard isRunning else { return }
        isPaused = true
    }

    func resume() {
        guard isRunning else { return }
        isPaused = false
    }

    @MainActor
    private func executeAllCycles(generation: Int) async {
        for cycle in 1...config.totalCycles {
            if generation != runGeneration { break }
            while isPaused && generation == runGeneration {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            if generation != runGeneration { break }
            let result = config.useLiveDevice
                ? await executeLiveCycle(cycleNumber: cycle, generation: generation)
                : await executeCycle(cycleNumber: cycle)
            metrics.record(result)
            metrics.snapshotMemory(cycle: cycle)
            onCycle?(result)
            if config.useLiveDevice && generation == runGeneration && cycle < config.totalCycles {
                let settle = Date().addingTimeInterval(0.4)
                while Date() < settle && generation == runGeneration && !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            }
        }
        if generation == runGeneration {
            isRunning = false
            runTask = nil
            onFinished?()
        }
    }

    @MainActor
    func executeCycle(cycleNumber: Int) async -> DemoStressCycleResult {
        let started = Date()
        let identifier = "stress-\(cycleNumber)-\(UUID().uuidString)"
        let raw = DemoStressPeripheral(identifier)
        let device = BLEPeripheral(raw)
        var failedPhase: DemoStressPhase?
        var message: String?
        var phaseDurations: [(phase: String, duration: TimeInterval)] = []
        var streams: [AsyncStream<BLEConnectionEvent>] = []
        var watchers: [Task<Void, Never>] = []

        func finish(_ phase: DemoStressPhase, began: Date, problem: String?) -> Bool {
            phaseDurations.append((phase: phase.rawValue, duration: Date().timeIntervalSince(began)))
            guard let problem = problem else { return true }
            failedPhase = phase
            message = problem
            return false
        }

        let claimBegan = Date()
        var claimProblem: String?
        for _ in 0..<config.subscriberCount {
            if let stream = device.observeConnection() {
                streams.append(stream)
            }
        }
        if streams.count != config.subscriberCount {
            claimProblem = "observeConnection returned nil"
        } else if raw.connectStateDelegate == nil {
            claimProblem = "delegate was not installed"
        } else if BZCentralManager.default().getPeripheral(identifier) !== raw {
            claimProblem = "device table missed this peripheral"
        }
        var keepGoing = finish(.claim, began: claimBegan, problem: claimProblem)

        if keepGoing {
            let signalBegan = Date()
            let expected = streams.count * 3
            let counter = DemoStressCounter()
            for stream in streams {
                watchers.append(Task {
                    for await _ in stream {
                        counter.increment()
                    }
                })
            }
            let signaled = Self.deliver("didConnectingPeripheral:", to: raw, object: raw)
                && Self.deliver("didConnected:", to: raw, object: raw)
                && Self.deliver("didDisconnected:error:", to: raw, object: raw, second: nil)
            if signaled {
                let deadline = Date().addingTimeInterval(2)
                while counter.value < expected && Date() < deadline {
                    try? await Task.sleep(nanoseconds: 2_000_000)
                }
            }
            let signalProblem: String?
            if !signaled {
                signalProblem = "bridge did not accept a session callback"
            } else if counter.value != expected {
                signalProblem = "expected \(expected) events, received \(counter.value)"
            } else {
                signalProblem = nil
            }
            keepGoing = finish(.signal, began: signalBegan, problem: signalProblem)
        }

        if keepGoing {
            let adoptBegan = Date()
            let temporary = DemoStressPeripheral(identifier)
            temporary.scannedRSSINumber = NSNumber(value: -63)
            var adoptProblem: String?
            if !device.adopt(temporary) {
                adoptProblem = "adopt rejected the advertisement"
            } else if device.rssi?.intValue != -63 {
                adoptProblem = "RSSI was not copied"
            } else if BZCentralManager.default().getPeripheral(identifier) !== raw {
                adoptProblem = "adopt replaced the table entry"
            }
            keepGoing = finish(.adopt, began: adoptBegan, problem: adoptProblem)
        }

        if keepGoing {
            let occupyBegan = Date()
            let other = BLEPeripheral(DemoStressPeripheral(identifier))
            var occupyProblem: String?
            if other.observeConnection() != nil {
                other.detach()
                occupyProblem = "an occupied identifier was claimed"
            } else if raw.connectStateDelegate == nil {
                occupyProblem = "occupy cleared the delegate"
            } else if BZCentralManager.default().getPeripheral(identifier) !== raw {
                occupyProblem = "occupy replaced the table entry"
            }
            keepGoing = finish(.occupy, began: occupyBegan, problem: occupyProblem)
        }

        if keepGoing {
            let discoverBegan = Date()
            let discovering = DemoStressFixedPeripheral()
            discovering.fixedState = .discovering
            var discoverProblem: String?
            do {
                try await BLEPeripheral(discovering).discoverIfIdle()
                discoverProblem = "discovery already in progress was accepted"
            } catch let error as BLEError {
                if case .invalidOperation = error {
                    discoverProblem = nil
                } else {
                    discoverProblem = "discovering returned \(error)"
                }
            } catch {
                discoverProblem = "discovering returned \(error)"
            }
            if discoverProblem == nil {
                do {
                    try await device.discoverIfIdle()
                    discoverProblem = "disconnected discovery succeeded"
                } catch let error as BLEError {
                    if case .disconnected = error {
                        discoverProblem = nil
                    } else {
                        discoverProblem = "disconnected discovery returned \(error)"
                    }
                } catch {
                    discoverProblem = "disconnected discovery returned \(error)"
                }
            }
            keepGoing = finish(.discover, began: discoverBegan, problem: discoverProblem)
        }

        let releaseBegan = Date()
        device.detach()
        watchers.forEach { $0.cancel() }
        let releaseProblem: String?
        if raw.connectStateDelegate != nil {
            releaseProblem = "delegate remained after detach"
        } else if BZCentralManager.default().getPeripheral(identifier) != nil {
            releaseProblem = "identifier remained in the device table"
        } else {
            releaseProblem = nil
        }
        _ = finish(.release, began: releaseBegan, problem: keepGoing ? releaseProblem : nil)

        return DemoStressCycleResult(
            id: cycleNumber,
            identifier: identifier,
            passed: failedPhase == nil && releaseProblem == nil,
            duration: Date().timeIntervalSince(started),
            failedPhase: failedPhase ?? (releaseProblem == nil ? nil : .release),
            message: message ?? releaseProblem,
            phaseDurations: phaseDurations
        )
    }

    private static func deliver(_ selector: String, to raw: BZPeripheral, object: Any?, second: Any? = nil) -> Bool {
        guard let delegate = raw.connectStateDelegate as? NSObject else { return false }
        let method = NSSelectorFromString(selector)
        guard delegate.responds(to: method) else { return false }
        if selector.contains("error:") {
            delegate.perform(method, with: object, with: second)
        } else if let object = object {
            delegate.perform(method, with: object)
        } else {
            delegate.perform(method)
        }
        return true
    }

    @MainActor
    private func executeLiveCycle(cycleNumber: Int, generation: Int) async -> DemoStressCycleResult {
        let started = Date()
        var failedPhase: DemoStressPhase?
        var message: String?
        var phaseDurations: [(phase: String, duration: TimeInterval)] = []
        var identifier = "live-\(cycleNumber)"
        var claimed: BLEPeripheral?
        var watcher: Task<Void, Never>?
        var scanTask: Task<Void, Never>?
        let events = DemoStressEvents()

        func finish(_ phase: DemoStressPhase, began: Date, problem: String?) -> Bool {
            phaseDurations.append((phase: phase.rawValue, duration: Date().timeIntervalSince(began)))
            guard let problem = problem else { return true }
            if failedPhase == nil {
                failedPhase = phase
                message = problem
            }
            return false
        }

        func stopped() -> Bool {
            Task.isCancelled || generation != runGeneration
        }

        defer {
            scanTask?.cancel()
            BLECentral.shared.stopScan()
            watcher?.cancel()
            if let device = claimed {
                if device.isConnected {
                    _ = device.disconnect()
                }
                device.detach()
            }
        }

        let scanBegan = Date()
        let tracked = trackedPeripherals()
        let connected = tracked.filter { $0.isConnected }
        let filter = DemoLiveSelection.normalized(config.deviceName)
        var selected: BLEPeripheral?
        var scanProblem: String?
        if !BLECentral.shared.isPoweredOn {
            scanProblem = "Bluetooth is off"
        } else if let pinned = pinnedLiveIdentifier, let device = rememberedPeripheral(identifier: pinned) {
            selected = device
        } else if let device = matchedTrackedDevice(tracked: tracked, connected: connected, filter: filter) {
            selected = device
        } else {
            let sightings = DemoLiveSightings()
            let scanEnded = DemoStressBox<Bool>()
            let stream = BLECentral.shared.scan(services: nil, allowDuplicates: true)
            scanTask = Task { @MainActor in
                for await advertisement in stream {
                    let name = advertisement.localName ?? advertisement.peripheral.name ?? ""
                    let rssi = advertisement.rssi?.intValue ?? Int.min
                    let id = advertisement.peripheral.uuidString
                    guard !id.isEmpty else { continue }
                    sightings.record(
                        name: name,
                        identifier: id,
                        rssi: rssi,
                        peripheral: advertisement.peripheral
                    )
                }
                scanEnded.set(true)
            }
            let deadline = Date().addingTimeInterval(8)
            var firstMatch: Date?
            while Date() < deadline && !stopped() && scanEnded.get() != true {
                if let pinned = pinnedLiveIdentifier, let device = sightings.peripheral(identifier: pinned) {
                    selected = device
                    break
                }
                if let chosen = DemoLiveSelection.choose(from: sightings.snapshot(), nameFilter: filter) {
                    if firstMatch == nil {
                        firstMatch = Date()
                    }
                    if let seen = firstMatch, Date().timeIntervalSince(seen) >= 1.5 {
                        selected = sightings.peripheral(identifier: chosen.identifier)
                        break
                    }
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            if selected == nil && !stopped() {
                if let pinned = pinnedLiveIdentifier, let device = sightings.peripheral(identifier: pinned) {
                    selected = device
                } else if let chosen = DemoLiveSelection.choose(from: sightings.snapshot(), nameFilter: filter) {
                    selected = sightings.peripheral(identifier: chosen.identifier)
                }
            }
            scanTask?.cancel()
            scanTask = nil
            BLECentral.shared.stopScan()
            if selected == nil {
                if stopped() {
                    scanProblem = "Stopped"
                } else if filter.isEmpty && connected.count > 1 {
                    scanProblem = "Several connected devices. Enter a name."
                } else {
                    scanProblem = "No device found"
                }
            }
        }
        var keepGoing = finish(.scan, began: scanBegan, problem: scanProblem)
        if let selected = selected {
            identifier = selected.uuidString
            pinnedLiveIdentifier = selected.uuidString
        }

        if keepGoing, let selected = selected {
            let connectBegan = Date()
            NotificationCenter.default.post(name: .demoStressReleaseDevice, object: selected.uuidString)
            let owned = claim(selected, events: events, watcher: &watcher)
            claimed = owned
            var connectProblem: String?
            if let device = owned {
                if device.isConnected {
                    connectProblem = nil
                } else if device.isConnecting {
                    connectProblem = await waitForConnection(events: events, generation: generation)
                } else if !device.connect() {
                    connectProblem = "Connect did not start"
                } else {
                    connectProblem = await waitForConnection(events: events, generation: generation)
                }
            } else {
                connectProblem = "Connection is already owned"
            }
            keepGoing = finish(.connect, began: connectBegan, problem: connectProblem)
        }

        if keepGoing, let device = claimed {
            let discoverBegan = Date()
            var discoverProblem = await waitForWork(seconds: 12, generation: generation) {
                try await device.discoverIfIdle()
            }
            if discoverProblem == "Discovery is already in progress" {
                let status = await waitUntil(seconds: 12, generation: generation) {
                    device.phase != .discovering || !device.isConnected
                }
                if status == nil && device.isConnected {
                    discoverProblem = await waitForWork(seconds: 12, generation: generation) {
                        try await device.discoverIfIdle()
                    }
                } else if status == "Timed out" {
                    discoverProblem = "Discover timed out"
                } else if let status = status {
                    discoverProblem = status
                }
            }
            keepGoing = finish(
                .discover,
                began: discoverBegan,
                problem: discoverProblem == "Timed out" ? "Discover timed out" : discoverProblem
            )
        }

        if keepGoing, let device = claimed {
            let readBegan = Date()
            let outcome = await readDiscoveredCharacteristics(device, generation: generation)
            keepGoing = finish(.read, began: readBegan, problem: outcome.problem)
            if outcome.problem == nil && failedPhase == nil {
                message = outcome.summary
            }
        }

        if keepGoing, let device = claimed {
            let rssiBegan = Date()
            let rssiProblem = await waitForWork(seconds: 6, generation: generation) {
                _ = try await device.readRSSI()
            }
            keepGoing = finish(
                .rssi,
                began: rssiBegan,
                problem: rssiProblem == "Timed out" ? "RSSI timed out" : rssiProblem
            )
        }

        if let device = claimed, device.isConnected {
            let disconnectBegan = Date()
            var disconnectProblem: String?
            if !device.disconnect() {
                disconnectProblem = "Disconnect did not start"
            } else {
                let status = await waitUntil(seconds: 8, generation: generation) {
                    events.hasDisconnected()
                }
                if status == "Timed out" {
                    disconnectProblem = "Disconnect timed out"
                } else {
                    disconnectProblem = status
                }
            }
            _ = finish(.disconnect, began: disconnectBegan, problem: keepGoing ? disconnectProblem : nil)
        }

        let releaseBegan = Date()
        let releasing = claimed
        claimed = nil
        releasing?.detach()
        _ = finish(.release, began: releaseBegan, problem: nil)

        return DemoStressCycleResult(
            id: cycleNumber,
            identifier: identifier,
            passed: failedPhase == nil,
            duration: Date().timeIntervalSince(started),
            failedPhase: failedPhase,
            message: message,
            phaseDurations: phaseDurations
        )
    }

    @MainActor
    private func claim(
        _ device: BLEPeripheral,
        events: DemoStressEvents,
        watcher: inout Task<Void, Never>?
    ) -> BLEPeripheral? {
        if let stream = device.observeConnection() {
            watcher = watch(stream, events: events)
            return device
        }
        guard let again = BLECentral.shared.peripheral(identifier: device.uuidString),
              let stream = again.observeConnection() else {
            return nil
        }
        watcher = watch(stream, events: events)
        return again
    }

    private func watch(
        _ stream: AsyncStream<BLEConnectionEvent>,
        events: DemoStressEvents
    ) -> Task<Void, Never> {
        Task {
            for await event in stream {
                events.append(event)
            }
        }
    }

    private func trackedPeripherals() -> [BLEPeripheral] {
        BLECentral.shared.peripherals.filter { !$0.uuidString.isEmpty }
    }

    /// The restored device stays connected and often does not advertise.
    /// Later cycles ask for that same identifier instead of the scan-page service list.
    private func rememberedPeripheral(identifier: String) -> BLEPeripheral? {
        if let tracked = trackedPeripherals().first(where: { $0.uuidString == identifier }) {
            return tracked
        }
        return BLECentral.shared.retrievePeripherals(identifiers: [identifier])
            .first { $0.uuidString == identifier }
    }

    private func matchedTrackedDevice(
        tracked: [BLEPeripheral],
        connected: [BLEPeripheral],
        filter: String
    ) -> BLEPeripheral? {
        let pool = filter.isEmpty ? connected : tracked
        guard let identifier = DemoLiveSelection.preferredConnectedIdentifier(
            devices: pool.map { (name: $0.name ?? "", identifier: $0.uuidString) },
            nameFilter: filter
        ) else {
            return nil
        }
        return pool.first { $0.uuidString == identifier }
    }

    @MainActor
    private func readDiscoveredCharacteristics(
        _ device: BLEPeripheral,
        generation: Int
    ) async -> (problem: String?, summary: String?) {
        if device.services.isEmpty {
            return ("No services", nil)
        }
        var readable: [CBCharacteristic] = []
        for service in device.services {
            for characteristic in service.characteristics ?? [] where characteristic.properties.contains(.read) {
                readable.append(characteristic)
            }
        }
        if readable.isEmpty {
            return ("No readable characteristic", nil)
        }
        var succeeded = 0
        var firstFailure: String?
        for characteristic in readable {
            if Task.isCancelled || generation != runGeneration {
                return ("Stopped", nil)
            }
            let label = characteristic.uuid.uuidString
            let problem = await waitForWork(seconds: 6, generation: generation) {
                _ = try await device.read(characteristic)
            }
            if problem == nil {
                succeeded += 1
                continue
            }
            if problem == "Timed out" || problem == "Stopped" || problem == "Device disconnected" {
                let text = problem == "Timed out" ? "Read timed out \(label)" : "\(problem ?? "Read failed") \(label)"
                return (text, nil)
            }
            if firstFailure == nil {
                firstFailure = "\(label) \(problem ?? "")"
            }
        }
        if succeeded == 0 {
            return ("Read failed \(firstFailure ?? "")", nil)
        }
        let summary = firstFailure == nil
            ? "Read \(succeeded)/\(readable.count)"
            : "Read \(succeeded)/\(readable.count), \(firstFailure ?? "")"
        return (nil, summary)
    }

    @MainActor
    private func waitForConnection(events: DemoStressEvents, generation: Int) async -> String? {
        let status = await waitUntil(seconds: 12, generation: generation) {
            events.hasConnected() || events.failureMessage() != nil
        }
        if events.hasConnected() {
            return nil
        }
        if let failure = events.failureMessage() {
            return failure
        }
        return status == "Timed out" ? "Connect timed out" : status
    }

    @MainActor
    private func waitUntil(
        seconds: TimeInterval,
        generation: Int,
        _ ready: () -> Bool
    ) async -> String? {
        let deadline = Date().addingTimeInterval(seconds)
        while !ready() && Date() < deadline {
            if Task.isCancelled || generation != runGeneration {
                return "Stopped"
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        if Task.isCancelled || generation != runGeneration {
            return "Stopped"
        }
        return ready() ? nil : "Timed out"
    }

    @MainActor
    private func waitForWork(
        seconds: TimeInterval,
        generation: Int,
        _ work: @escaping () async throws -> Void
    ) async -> String? {
        let box = DemoStressBox<Result<Void, Error>>()
        let task = Task { @MainActor in
            do {
                try await work()
                box.set(.success(()))
            } catch {
                box.set(.failure(error))
            }
        }
        let deadline = Date().addingTimeInterval(seconds)
        while box.get() == nil && Date() < deadline {
            if Task.isCancelled || generation != runGeneration {
                task.cancel()
                return "Stopped"
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        if let result = box.get() {
            switch result {
            case .success:
                return nil
            case .failure(let error):
                return demoStressMessage(error)
            }
        }
        task.cancel()
        if Task.isCancelled || generation != runGeneration {
            return "Stopped"
        }
        return "Timed out"
    }
}

private func demoStressMessage(_ error: Error) -> String {
    guard let ble = error as? BLEError else { return error.localizedDescription }
    switch ble {
    case .disconnected:
        return "Device disconnected"
    case .gatt:
        return "GATT error"
    case .scanFailed:
        return "Scan failed"
    case .invalidOperation(let message):
        return message
    case .underlying(let wrapped):
        return wrapped.localizedDescription
    }
}

private final class DemoStressBox<T> {
    private let lock = NSLock()
    private var storage: T?

    func set(_ value: T) {
        lock.lock()
        storage = value
        lock.unlock()
    }

    func get() -> T? {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private final class DemoStressEvents {
    private let lock = NSLock()
    private var storage: [BLEConnectionEvent] = []

    func append(_ event: BLEConnectionEvent) {
        lock.lock()
        storage.append(event)
        lock.unlock()
    }

    func hasConnected() -> Bool {
        contains { event in
            switch event {
            case .connected, .restored, .retrievedConnected:
                return true
            default:
                return false
            }
        }
    }

    func hasDisconnected() -> Bool {
        contains { event in
            if case .disconnected = event { return true }
            return false
        }
    }

    func failureMessage() -> String? {
        lock.lock()
        defer { lock.unlock() }
        for event in storage {
            if case .failed(_, let error) = event {
                return demoStressMessage(error)
            }
        }
        return nil
    }

    private func contains(_ match: (BLEConnectionEvent) -> Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage.contains(where: match)
    }
}

private final class DemoLiveSightings {
    private let lock = NSLock()
    private var devices: [String: BLEPeripheral] = [:]
    private var candidates: [DemoLiveCandidate] = []

    func record(name: String, identifier: String, rssi: Int, peripheral: BLEPeripheral) {
        lock.lock()
        devices[identifier] = peripheral
        if let index = candidates.firstIndex(where: { $0.identifier == identifier }) {
            var current = candidates[index]
            if !name.isEmpty {
                current.name = name
            }
            if rssi > current.rssi {
                current.rssi = rssi
            }
            candidates[index] = current
        } else {
            candidates.append(DemoLiveCandidate(name: name, identifier: identifier, rssi: rssi))
        }
        lock.unlock()
    }

    func snapshot() -> [DemoLiveCandidate] {
        lock.lock()
        defer { lock.unlock() }
        return candidates
    }

    func peripheral(identifier: String) -> BLEPeripheral? {
        lock.lock()
        defer { lock.unlock() }
        return devices[identifier]
    }
}

private final class DemoStressCounter {
    private let lock = NSLock()
    private var storage = 0

    func increment() {
        lock.lock()
        storage += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        let current = storage
        lock.unlock()
        return current
    }
}

private final class DemoStressPeripheral: BZPeripheral {
    private let identifier: String

    init(_ identifier: String) {
        self.identifier = identifier
        super.init()
    }

    override var uuidString: String? {
        identifier
    }
}

private final class DemoStressFixedPeripheral: BZPeripheral {
    var fixedState: BZPeripheralState = .disconnected

    override var state: BZPeripheralState {
        fixedState
    }
}
