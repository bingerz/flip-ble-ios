import SnapKit
import UIKit

/// Repeats one library session many times.
/// Live device is off by default. Turning it on runs each cycle against a nearby radio.
final class BZStressTestViewController: UIViewController {
    private let engine = DemoStressEngine()
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let noteLabel = UILabel()
    private let liveSwitch = UISwitch()
    private let deviceNameField = UITextField()
    private let cycleField = UITextField()
    private let subscriberValue = UILabel()
    private let subscriberStepper = UIStepper()
    private let statusLabel = DemoChipLabel()
    private let progressLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let summaryLabel = UILabel()
    private let phaseLabel = UILabel()
    private let memoryLabel = UILabel()
    private let logView = UITextView()
    private let startButton = UIButton(type: .system)
    private let pauseButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)
    private let resetButton = UIButton(type: .system)
    private var recentResults: [DemoStressCycleResult] = []
    private var subscriberCount = DemoStressConfig.default.subscriberCount

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Stress"
        view.backgroundColor = DemoStyle.canvas
        setupViews()
        engine.onCycle = { [weak self] result in
            self?.performOnMain { self?.append(result) }
        }
        engine.onFinished = { [weak self] in
            self?.performOnMain { self?.finishRun() }
        }
        refresh()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            engine.stop()
        }
    }

    private func setupViews() {
        scrollView.keyboardDismissMode = .onDrag
        stack.axis = .vertical
        stack.spacing = 12
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        stack.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide).inset(16)
            make.width.equalTo(scrollView.frameLayoutGuide).offset(-32)
        }

        noteLabel.numberOfLines = 0
        DemoStyle.applyLabel(noteLabel, style: .footnote, color: DemoStyle.slate)

        liveSwitch.addTarget(self, action: #selector(liveSwitchChanged), for: .valueChanged)
        liveSwitch.accessibilityLabel = "Live device"

        deviceNameField.borderStyle = .roundedRect
        deviceNameField.autocapitalizationType = .none
        deviceNameField.autocorrectionType = .no
        deviceNameField.clearButtonMode = .whileEditing
        deviceNameField.placeholder = "Optional name, such as nut"
        deviceNameField.font = UIFont.preferredFont(forTextStyle: .body)
        deviceNameField.adjustsFontForContentSizeCategory = true
        deviceNameField.accessibilityLabel = "Device name"
        deviceNameField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        deviceNameField.addTarget(self, action: #selector(dismissKeyboard), for: .editingDidEndOnExit)

        cycleField.borderStyle = .roundedRect
        cycleField.keyboardType = .numberPad
        cycleField.text = "\(DemoStressConfig.default.totalCycles)"
        cycleField.placeholder = "200"
        cycleField.font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)
        cycleField.accessibilityLabel = "Cycle count"

        subscriberStepper.minimumValue = 1
        subscriberStepper.maximumValue = 8
        subscriberStepper.value = Double(subscriberCount)
        subscriberStepper.addTarget(self, action: #selector(subscriberChanged), for: .valueChanged)
        DemoStyle.applyLabel(subscriberValue, style: .body)
        subscriberValue.text = "\(subscriberCount)"
        subscriberValue.setContentHuggingPriority(.required, for: .horizontal)

        DemoStyle.applyFilled(startButton, title: "Start", color: DemoStyle.primaryFill, titleColor: DemoStyle.onPrimaryFill)
        DemoStyle.applyOutline(pauseButton, title: "Pause", color: DemoStyle.amber)
        DemoStyle.applyOutline(stopButton, title: "Stop", color: .systemRed)
        DemoStyle.applyOutline(resetButton, title: "Reset", color: DemoStyle.slate)
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        pauseButton.addTarget(self, action: #selector(pauseTapped), for: .touchUpInside)
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)

        progressView.trackTintColor = DemoStyle.barTrack
        progressView.progressTintColor = DemoStyle.accent
        progressView.layer.cornerRadius = 2
        progressView.clipsToBounds = true
        DemoStyle.applyLabel(progressLabel, style: .caption1, color: DemoStyle.slate)
        DemoStyle.applyLabel(summaryLabel, style: .subheadline)
        summaryLabel.numberOfLines = 0
        DemoStyle.applyLabel(phaseLabel, style: .footnote, color: DemoStyle.slate)
        phaseLabel.numberOfLines = 0
        DemoStyle.applyLabel(memoryLabel, style: .footnote, color: DemoStyle.slate)
        memoryLabel.numberOfLines = 0

        logView.isEditable = false
        logView.isScrollEnabled = false
        logView.backgroundColor = .clear
        logView.textContainerInset = .zero
        logView.textContainer.lineFragmentPadding = 0
        logView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        logView.accessibilityLabel = "Cycle log"

        stack.addArrangedSubview(noteLabel)
        stack.addArrangedSubview(card(title: "Run", rows: [
            labeled("Live device", trailingSwitch()),
            labeled("Name", deviceNameField),
            labeled("Cycles", cycleField),
            labeled("Subscribers", subscriberRow()),
            buttonRow()
        ]))
        stack.addArrangedSubview(card(title: "Status", rows: [statusRow(), progressLabel, progressView]))
        stack.addArrangedSubview(card(title: "Result", rows: [summaryLabel, phaseLabel, memoryLabel]))
        stack.addArrangedSubview(card(title: "Recent cycles", rows: [logView]))
    }

    private func card(title: String, rows: [UIView]) -> UIView {
        let card = UIView()
        card.backgroundColor = DemoStyle.card
        card.layer.cornerRadius = 12
        card.layer.borderWidth = 1
        DemoStyle.refreshBorder(of: card.layer, color: DemoStyle.hairline, traits: traitCollection)
        let titleLabel = UILabel()
        DemoStyle.applyLabel(titleLabel, style: .headline, weight: .semibold)
        titleLabel.text = title
        let column = UIStackView(arrangedSubviews: [titleLabel] + rows)
        column.axis = .vertical
        column.spacing = 8
        card.addSubview(column)
        column.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
        return card
    }

    private func labeled(_ title: String, _ content: UIView) -> UIView {
        let label = UILabel()
        DemoStyle.applyLabel(label, style: .subheadline)
        label.text = title
        label.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [label, content])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        return row
    }

    private func trailingSwitch() -> UIView {
        let spacer = UIView()
        let row = UIStackView(arrangedSubviews: [spacer, liveSwitch])
        row.axis = .horizontal
        row.alignment = .center
        return row
    }

    private func subscriberRow() -> UIView {
        let row = UIStackView(arrangedSubviews: [subscriberValue, subscriberStepper])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        return row
    }

    private func buttonRow() -> UIView {
        let row = UIStackView(arrangedSubviews: [startButton, pauseButton, stopButton, resetButton])
        row.axis = .horizontal
        row.spacing = 8
        row.distribution = .fillEqually
        row.alignment = .center
        return row
    }

    private func statusRow() -> UIView {
        let spacer = UIView()
        let row = UIStackView(arrangedSubviews: [statusLabel, spacer])
        row.axis = .horizontal
        row.alignment = .center
        return row
    }

    @objc private func liveSwitchChanged() {
        refresh()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func subscriberChanged() {
        subscriberCount = Int(subscriberStepper.value)
        subscriberValue.text = "\(subscriberCount)"
    }

    @objc private func startTapped() {
        view.endEditing(true)
        var config = DemoStressConfig.default
        config.totalCycles = Int(cycleField.text ?? "") ?? DemoStressConfig.default.totalCycles
        config.subscriberCount = subscriberCount
        config.useLiveDevice = liveSwitch.isOn
        config.deviceName = deviceNameField.text ?? ""
        engine.config = config
        cycleField.text = "\(config.clampedCycles)"
        recentResults.removeAll()
        engine.start()
        refresh()
    }

    @objc private func pauseTapped() {
        if engine.isPaused {
            engine.resume()
        } else {
            engine.pause()
        }
        refresh()
    }

    @objc private func stopTapped() {
        engine.stop()
        refresh()
    }

    @objc private func resetTapped() {
        engine.stop()
        engine.metrics.reset()
        recentResults.removeAll()
        refresh()
    }

    private func performOnMain(_ body: @escaping () -> Void) {
        if Thread.isMainThread {
            body()
        } else {
            DispatchQueue.main.async(execute: body)
        }
    }

    private func append(_ result: DemoStressCycleResult) {
        recentResults.append(result)
        if recentResults.count > 40 {
            recentResults.removeFirst(recentResults.count - 40)
        }
        refresh()
    }

    private func finishRun() {
        refresh()
        let metrics = engine.metrics
        let alert = UIAlertController(
            title: "Stress test complete",
            message: "Completed \(metrics.totalCycles) cycles: \(metrics.passedCycles) passed, \(metrics.failedCycles) failed.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func refresh() {
        let metrics = engine.metrics
        let total = max(engine.config.totalCycles, 1)
        let running = engine.isRunning
        let live = liveSwitch.isOn
        noteLabel.text = live
            ? "Each cycle uses the restored connected device when there is only one, then reconnects that same device. It discovers services, reads every readable characteristic, reads RSSI, and disconnects. It does not write or subscribe. Enter a name such as nut when several devices are nearby."
            : "Repeats claim, signal, adopt, occupy, discover, and release on the library. The radio stays off."
        liveSwitch.isEnabled = !running
        deviceNameField.isEnabled = live && !running
        cycleField.isEnabled = !running
        subscriberStepper.isEnabled = !running && !live
        subscriberValue.textColor = subscriberStepper.isEnabled ? .label : DemoStyle.slate
        startButton.isEnabled = !running
        resetButton.isEnabled = !running
        pauseButton.isEnabled = running
        stopButton.isEnabled = running
        DemoStyle.applyOutline(pauseButton, title: engine.isPaused ? "Resume" : "Pause", color: DemoStyle.amber)

        if running && engine.isPaused {
            statusLabel.apply(text: "Paused", foreground: DemoStyle.amber, background: DemoStyle.chipFill)
        } else if running {
            statusLabel.apply(text: "Running", foreground: DemoStyle.accent, background: DemoStyle.chipFill)
        } else if metrics.failedCycles > 0 {
            statusLabel.apply(text: "Failed", foreground: .systemRed, background: DemoStyle.chipFill)
        } else if metrics.totalCycles > 0 {
            statusLabel.apply(text: "Passed", foreground: DemoStyle.accent, background: DemoStyle.chipFill)
        } else {
            statusLabel.apply(text: "Idle", foreground: DemoStyle.slate, background: DemoStyle.chipFill)
        }

        progressLabel.text = "\(metrics.totalCycles) / \(engine.config.clampedCycles)"
        progressView.progress = Float(metrics.totalCycles) / Float(total)
        summaryLabel.text = "Passed \(metrics.passedCycles)    Failed \(metrics.failedCycles)\nAvg \(Self.format(metrics.averageCycleDuration))    Min \(Self.format(metrics.minCycleDuration))    Max \(Self.format(metrics.maxCycleDuration))"
        phaseLabel.text = phaseSummary(metrics)
        let delta = metrics.memoryDeltaMB
        let sign = delta >= 0 ? "+" : ""
        memoryLabel.text = String(format: "Memory %.1f MB (%@%.1f)", metrics.latestMemoryMB, sign, delta)
        logView.attributedText = logText()
    }

    private func phaseSummary(_ metrics: DemoStressMetrics) -> String {
        let timings = DemoStressPhase.allCases.compactMap { phase -> String? in
            guard let timing = metrics.phaseTimings[phase.rawValue], timing.count > 0 else { return nil }
            let failures = metrics.errorDistribution[phase] ?? 0
            let failureText = failures > 0 ? ", \(failures) failed" : ""
            return "\(phase.rawValue) \(Self.format(timing.averageDuration))\(failureText)"
        }
        return timings.isEmpty ? "No phase timings yet." : timings.joined(separator: "\n")
    }

    private func logText() -> NSAttributedString {
        let text = NSMutableAttributedString()
        let body = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        if recentResults.isEmpty {
            text.append(NSAttributedString(string: "No cycles yet.", attributes: [
                .font: body,
                .foregroundColor: DemoStyle.slate
            ]))
            return text
        }
        for result in recentResults.reversed() {
            let line = "#\(result.id)  \(result.passed ? "passed" : "failed")  \(Self.format(result.duration))"
            let detail = result.message.map { "  \($0)" } ?? ""
            let color: UIColor = result.passed ? .label : .systemRed
            text.append(NSAttributedString(string: line + detail + "\n", attributes: [
                .font: body,
                .foregroundColor: color
            ]))
        }
        return text
    }

    private static func format(_ interval: TimeInterval) -> String {
        let milliseconds = interval * 1000
        if milliseconds < 100 {
            return String(format: "%.1f ms", milliseconds)
        }
        return String(format: "%.0f ms", milliseconds)
    }
}
