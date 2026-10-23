import CoreBluetooth
import Flip_BLE
import SnapKit
import UIKit

class BZConsoleViewController: UIViewController {

    var peripheral: BLEPeripheral?
    var characteristic: CBCharacteristic?
    var action: DemoGATTAction = .read

    private let connectionWatch = DemoConnectionWatch()
    private let logView = UITextView()
    private let hexField = UITextField()
    private let hexHintLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private let busySpinner = UIActivityIndicatorView(style: .medium)
    private let notifySwitch = UISwitch()
    private let notifyLabel = UILabel()
    private var notifyTask: Task<Void, Never>?
    private var isBusy = false

    private var cacheKey: String {
        DemoConsoleStore.key(
            peripheralID: peripheral?.uuidString ?? "",
            characteristicUUID: characteristic?.uuid.uuidString ?? "",
            action: action
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DemoStyle.canvas
        title = "Console"
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Copy", style: .plain, target: self, action: #selector(copyLog)),
            UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearLog))
        ]
        logView.isEditable = false
        logView.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        logView.adjustsFontForContentSizeCategory = true
        logView.backgroundColor = DemoStyle.card
        logView.textColor = .label
        logView.layer.borderWidth = 1
        logView.layer.cornerRadius = 8
        DemoStyle.refreshBorder(of: logView.layer, color: .separator, traits: traitCollection)
        hexField.placeholder = "HEX format command"
        hexField.font = DemoStyle.font(.subheadline)
        hexField.adjustsFontForContentSizeCategory = true
        hexField.borderStyle = .roundedRect
        hexField.backgroundColor = .secondarySystemBackground
        hexField.textColor = .label
        hexField.autocapitalizationType = .allCharacters
        hexField.autocorrectionType = .no
        DemoStyle.applyLabel(hexHintLabel, style: .caption1, color: .systemRed)
        hexHintLabel.numberOfLines = 0
        hexHintLabel.isHidden = true
        DemoStyle.applyLabel(notifyLabel, style: .body)
        switch action {
        case .read, .write, .writeWithoutResponse:
            DemoStyle.applyFilled(actionButton, title: action.title, color: DemoStyle.primaryFill, titleColor: DemoStyle.onPrimaryFill)
        case .notify, .indicate:
            break
        }
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        notifySwitch.addTarget(self, action: #selector(notifyChanged), for: .valueChanged)
        busySpinner.hidesWhenStopped = true

        view.addSubview(logView)
        logView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(12)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }
        let entry = DemoConsoleStore.shared.entry(for: cacheKey)
        logView.text = entry.text
        layoutControls(restoredOn: entry.isOn)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        connectionWatch.start(peripheral: peripheral, navigationController: navigationController)
        if action == .notify || action == .indicate {
            let entry = DemoConsoleStore.shared.entry(for: cacheKey)
            if entry.isOn, notifyTask == nil {
                notifySwitch.isOn = true
                updateNotifyLabel(on: true)
                startSubscription()
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        DemoStyle.refreshBorder(of: logView.layer, color: .separator, traits: traitCollection)
        if actionButton.superview != nil, action == .read || action == .write || action == .writeWithoutResponse {
            DemoStyle.applyFilled(actionButton, title: action.title, color: DemoStyle.primaryFill, titleColor: DemoStyle.onPrimaryFill)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        connectionWatch.stop()
        notifyTask?.cancel()
        notifyTask = nil
        persist()
    }

    private func layoutControls(restoredOn: Bool) {
        let bottom = UIStackView()
        bottom.axis = .vertical
        bottom.spacing = 10
        bottom.alignment = .fill
        view.addSubview(bottom)
        bottom.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-16)
        }
        logView.snp.makeConstraints { make in
            make.bottom.equalTo(bottom.snp.top).offset(-12)
        }

        switch action {
        case .read:
            bottom.addArrangedSubview(centeredActionRow())
        case .write, .writeWithoutResponse:
            hexField.snp.makeConstraints { make in
                make.height.equalTo(38)
            }
            bottom.addArrangedSubview(hexField)
            bottom.addArrangedSubview(hexHintLabel)
            bottom.addArrangedSubview(centeredActionRow())
        case .notify, .indicate:
            notifySwitch.isOn = restoredOn
            updateNotifyLabel(on: restoredOn)
            let row = UIStackView(arrangedSubviews: [notifyLabel, notifySwitch])
            row.axis = .horizontal
            row.spacing = 12
            row.alignment = .center
            bottom.alignment = .center
            bottom.addArrangedSubview(row)
        }
    }

    private func centeredActionRow() -> UIStackView {
        let row = UIStackView(arrangedSubviews: [actionButton, busySpinner])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center
        let wrap = UIStackView(arrangedSubviews: [row])
        wrap.axis = .vertical
        wrap.alignment = .center
        return wrap
    }

    private func updateNotifyLabel(on: Bool) {
        notifyLabel.text = on
            ? (action == .notify ? "Disable Notification" : "Disable Indicate")
            : (action == .notify ? "Enable Notification" : "Enable Indicate")
    }

    private func persist() {
        let isOn = (action == .notify || action == .indicate) ? notifySwitch.isOn : false
        DemoConsoleStore.shared.save(text: logView.text ?? "", isOn: isOn, for: cacheKey)
    }

    @objc private func clearLog() {
        logView.text = ""
        DemoConsoleStore.shared.clear(for: cacheKey)
        // Keep switch state after clear.
        let wasOn = notifySwitch.isOn
        if action == .notify || action == .indicate {
            DemoConsoleStore.shared.save(text: "", isOn: wasOn, for: cacheKey)
        }
    }

    @objc private func copyLog() {
        UIPasteboard.general.string = logView.text ?? ""
        DemoFeedback.show(message: "Log copied", in: view)
    }

    private func setBusy(_ busy: Bool) {
        isBusy = busy
        actionButton.isEnabled = !busy
        if busy {
            busySpinner.startAnimating()
        } else {
            busySpinner.stopAnimating()
        }
    }

    @objc private func actionTapped() {
        guard let peripheral = peripheral, let characteristic = characteristic else { return }
        switch action {
        case .read:
            setBusy(true)
            Task { @MainActor in
                defer { self.setBusy(false) }
                do {
                    let data = try await peripheral.read(characteristic)
                    self.append("Read \(DemoHex.string(from: data))")
                } catch {
                    self.append("Read failed: \(error.localizedDescription)")
                }
            }
        case .write, .writeWithoutResponse:
            let text = hexField.text ?? ""
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                hexHintLabel.text = "Enter a HEX command"
                hexHintLabel.isHidden = false
                return
            }
            guard let data = DemoHex.data(from: text) else {
                hexHintLabel.text = "Invalid HEX"
                hexHintLabel.isHidden = false
                append("Invalid HEX")
                return
            }
            hexHintLabel.isHidden = true
            setBusy(true)
            Task { @MainActor in
                defer { self.setBusy(false) }
                do {
                    _ = try await peripheral.write(characteristic, data)
                    self.append("\(self.action.title) \(DemoHex.string(from: data))")
                } catch {
                    self.append("\(self.action.title) failed: \(error.localizedDescription)")
                }
            }
        case .notify, .indicate:
            break
        }
    }

    @objc private func notifyChanged() {
        let enabled = notifySwitch.isOn
        updateNotifyLabel(on: enabled)
        persist()
        if enabled {
            startSubscription()
        } else {
            notifyTask?.cancel()
            notifyTask = nil
        }
    }

    private func startSubscription() {
        guard let peripheral = peripheral, let characteristic = characteristic else { return }
        notifyTask?.cancel()
        let stream: AsyncThrowingStream<Data, Error> = action == .notify
            ? peripheral.notify(characteristic)
            : peripheral.indicate(characteristic)
        notifyTask = Task { @MainActor in
            do {
                for try await data in stream {
                    self.append("\(self.action.title) \(DemoHex.string(from: data))")
                }
            } catch {
                if !Task.isCancelled {
                    self.append("\(self.action.title) failed: \(error.localizedDescription)")
                    self.notifySwitch.isOn = false
                    self.updateNotifyLabel(on: false)
                    self.persist()
                }
            }
        }
    }

    private func append(_ line: String) {
        logView.text = (logView.text ?? "") + line + "\n"
        persist()
        let range = NSRange(location: max((logView.text ?? "").count - 1, 0), length: 1)
        logView.scrollRangeToVisible(range)
    }
}
