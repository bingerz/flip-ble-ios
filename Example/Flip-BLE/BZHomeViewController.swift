import CoreBluetooth
import Flip_BLE
import SnapKit
import UIKit

private enum DeviceLinkState {
    case scanned
    case connecting
    case connected
}

private final class DemoDevice {
    let peripheral: BLEPeripheral
    var state: DeviceLinkState
    var displayName: String
    var advertisementData: [String: Any]

    init(peripheral: BLEPeripheral, displayName: String, advertisementData: [String: Any] = [:]) {
        self.peripheral = peripheral
        self.state = .scanned
        self.displayName = displayName
        self.advertisementData = advertisementData
    }

    var identifier: String {
        peripheral.uuidString
    }
}

private final class DemoDeviceCell: UITableViewCell {
    var onConnect: (() -> Void)?
    var onDisconnect: (() -> Void)?
    var onEnter: (() -> Void)?

    private let card = UIView()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let rssiLabel = UILabel()
    private let unitLabel = UILabel()
    private let signalBars = DemoSignalBars()
    private let statusLabel = DemoChipLabel()
    private let iconWell = UIView()
    private let iconView = UIImageView()
    private let chipStack = UIStackView()
    private let connectButton = UIButton(type: .system)
    private let disconnectButton = UIButton(type: .system)
    private let enterButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        card.layer.cornerRadius = 12
        card.layer.borderWidth = 1
        refreshCard()

        DemoStyle.applyLabel(nameLabel, style: .headline, weight: .semibold)
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        DemoStyle.applyIdentifier(detailLabel, color: DemoStyle.slate)
        let rssiFont = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        rssiLabel.font = UIFontMetrics(forTextStyle: .callout).scaledFont(for: rssiFont)
        rssiLabel.adjustsFontForContentSizeCategory = true
        rssiLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        DemoStyle.applyLabel(unitLabel, style: .caption2, color: DemoStyle.slate)
        unitLabel.text = "dBm"
        statusLabel.apply(text: "Connected", foreground: DemoStyle.accent, background: DemoStyle.chipFill)

        iconView.image = UIImage(systemName: "wave.3.right")
        iconView.contentMode = .scaleAspectFit
        iconWell.layer.cornerRadius = 8
        iconWell.clipsToBounds = true

        DemoStyle.applyFilled(connectButton, title: "Connect", color: DemoStyle.primaryFill, titleColor: DemoStyle.onPrimaryFill)
        DemoStyle.applyOutline(disconnectButton, title: "Disconnect", color: .systemRed)
        DemoStyle.applyFilled(enterButton, title: "Enter", color: DemoStyle.primaryFill, titleColor: DemoStyle.onPrimaryFill)
        connectButton.accessibilityLabel = "Connect"
        disconnectButton.accessibilityLabel = "Disconnect"
        enterButton.accessibilityLabel = "Enter device"
        connectButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        disconnectButton.addTarget(self, action: #selector(disconnectTapped), for: .touchUpInside)
        enterButton.addTarget(self, action: #selector(enterTapped), for: .touchUpInside)
        spinner.hidesWhenStopped = true
        for button in [connectButton, disconnectButton, enterButton] {
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.setContentHuggingPriority(.required, for: .horizontal)
        }

        chipStack.axis = .horizontal
        chipStack.spacing = 6
        chipStack.alignment = .center
        chipStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let signalRow = UIStackView(arrangedSubviews: [rssiLabel, unitLabel, signalBars])
        signalRow.axis = .horizontal
        signalRow.alignment = .center
        signalRow.spacing = 4
        signalRow.setContentCompressionResistancePriority(.required, for: .horizontal)
        signalRow.setContentHuggingPriority(.required, for: .horizontal)
        let topRow = UIStackView(arrangedSubviews: [iconWell, textStack, signalRow])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 10

        let actionStack = UIStackView(arrangedSubviews: [connectButton, disconnectButton, enterButton, spinner])
        actionStack.axis = .horizontal
        actionStack.spacing = 8
        actionStack.alignment = .center
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let actionRow = UIStackView(arrangedSubviews: [statusLabel, chipStack, spacer, actionStack])
        actionRow.axis = .horizontal
        actionRow.alignment = .center
        actionRow.spacing = 8

        let column = UIStackView(arrangedSubviews: [topRow, actionRow])
        column.axis = .vertical
        column.spacing = 10
        iconWell.addSubview(iconView)
        card.addSubview(column)
        contentView.addSubview(card)

        iconWell.snp.makeConstraints { make in
            make.width.height.equalTo(32)
        }
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(16)
        }
        card.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(6)
            make.bottom.equalToSuperview().offset(-6)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }
        column.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        refreshCard()
        DemoStyle.applyFilled(connectButton, title: "Connect", color: DemoStyle.primaryFill, titleColor: DemoStyle.onPrimaryFill)
        DemoStyle.refreshBorder(of: disconnectButton.layer, color: .systemRed, traits: traitCollection)
        DemoStyle.applyFilled(enterButton, title: "Enter", color: DemoStyle.primaryFill, titleColor: DemoStyle.onPrimaryFill)
        statusLabel.apply(text: "Connected", foreground: DemoStyle.accent, background: DemoStyle.chipFill)
    }

    private func refreshCard() {
        card.backgroundColor = DemoStyle.card
        iconWell.backgroundColor = DemoStyle.chipFill
        iconView.tintColor = DemoStyle.primaryFill
        DemoStyle.refreshBorder(of: card.layer, color: DemoStyle.hairline, traits: traitCollection)
    }

    func update(_ device: DemoDevice) {
        nameLabel.text = device.displayName
        detailLabel.text = device.identifier
        let rssi = device.peripheral.rssi?.intValue
        if let rssi = rssi {
            rssiLabel.text = "\(rssi)"
            rssiLabel.textColor = DemoSignal.color(for: rssi)
        } else {
            rssiLabel.text = "—"
            rssiLabel.textColor = DemoStyle.slate
        }
        signalBars.apply(rssi: rssi)
        reloadChips(DemoAdvertisementSummary.chips(from: device.advertisementData))
        let connected = device.state == .connected
        statusLabel.isHidden = !connected
        chipStack.isHidden = connected || chipStack.arrangedSubviews.isEmpty
        switch device.state {
        case .scanned:
            connectButton.isHidden = false
            disconnectButton.isHidden = true
            enterButton.isHidden = true
            spinner.stopAnimating()
        case .connecting:
            connectButton.isHidden = true
            disconnectButton.isHidden = true
            enterButton.isHidden = true
            spinner.startAnimating()
        case .connected:
            connectButton.isHidden = true
            disconnectButton.isHidden = false
            enterButton.isHidden = false
            spinner.stopAnimating()
        }
    }

    private func reloadChips(_ texts: [String]) {
        chipStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for text in texts {
            let chip = DemoChipLabel()
            chip.apply(text: text, foreground: DemoStyle.slate, background: DemoStyle.chipFill)
            chip.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            chip.lineBreakMode = .byTruncatingTail
            chipStack.addArrangedSubview(chip)
        }
    }

    @objc private func connectTapped() { onConnect?() }
    @objc private func disconnectTapped() { onDisconnect?() }
    @objc private func enterTapped() { onEnter?() }
}

class BZHomeViewController: UITableViewController {

    private let cellId = "DemoDeviceCell"
    private let central = BLECentral.shared

    private var devices: [DemoDevice] = []
    private var isScanning = false
    private var stateTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?

    private let headerView = UIView()
    private let filterStack = UIStackView()
    private let nameField = UITextField()
    private let identifierField = UITextField()
    private let uuidField = UITextField()
    private let uuidHintLabel = UILabel()
    private let filterToggleButton = UIButton(type: .system)
    private let scanButton = UIButton(type: .system)
    private let scanSpinner = UIActivityIndicatorView(style: .medium)
    private let scanStateLabel = DemoChipLabel()
    private let countLabel = UILabel()
    private var filtersExpanded = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "flipBLE"
        view.backgroundColor = DemoStyle.canvas
        tableView.backgroundColor = DemoStyle.canvas
        tableView.separatorStyle = .none
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Sort", style: .plain, target: self, action: #selector(sortDevices))
        tableView.register(DemoDeviceCell.self, forCellReuseIdentifier: cellId)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 92
        tableView.keyboardDismissMode = .onDrag
        setupHeader()
        startCentral()
        NotificationCenter.default.addObserver(self, selector: #selector(deviceDisconnected(_:)), name: .demoPeripheralDisconnected, object: nil)
        refreshList()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        for device in devices where device.state == .connected && !device.peripheral.isConnected {
            device.state = .scanned
        }
        refillConnectedDevices()
        refreshList()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func refreshList() {
        tableView.reloadData()
        let count = devices.count
        countLabel.text = count == 1 ? "1 peripheral" : "\(count) peripherals"
        scanStateLabel.apply(
            text: isScanning ? "SCANNING" : "IDLE",
            foreground: isScanning ? DemoStyle.accent : DemoStyle.slate,
            background: DemoStyle.chipFill
        )
        let text = isScanning ? "Scanning…\nNo matching devices yet" : "No devices yet\nTap Start Scan to search nearby BLE devices"
        DemoStyle.refreshEmptyState(for: tableView, rowCount: devices.count, text: text)
    }

    private func setupHeader() {
        headerView.backgroundColor = DemoStyle.canvas
        configureField(nameField, placeholder: "Name, comma-separated")
        configureField(identifierField, placeholder: "Identifier, comma-separated")
        configureField(uuidField, placeholder: "Service UUID, comma-separated")
        nameField.addTarget(self, action: #selector(nameOrIdentifierFilterChanged), for: .editingChanged)
        identifierField.addTarget(self, action: #selector(nameOrIdentifierFilterChanged), for: .editingChanged)
        uuidField.addTarget(self, action: #selector(uuidFieldChanged), for: .editingChanged)
        filterStack.axis = .vertical
        filterStack.spacing = 8
        filterStack.addArrangedSubview(nameField)
        filterStack.addArrangedSubview(identifierField)
        filterStack.addArrangedSubview(uuidField)
        filterStack.isHidden = true

        DemoStyle.applyLabel(uuidHintLabel, style: .caption1, color: .systemOrange)
        uuidHintLabel.numberOfLines = 0
        uuidHintLabel.isHidden = true

        filterToggleButton.setTitle("Expand scanning settings", for: .normal)
        filterToggleButton.titleLabel?.font = DemoStyle.font(.footnote)
        filterToggleButton.titleLabel?.adjustsFontForContentSizeCategory = true
        filterToggleButton.addTarget(self, action: #selector(toggleFilters), for: .touchUpInside)

        DemoStyle.applyFilled(scanButton, title: "Start Scan", color: DemoStyle.primaryFill, titleColor: DemoStyle.onPrimaryFill)
        scanButton.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        scanSpinner.hidesWhenStopped = true
        scanStateLabel.apply(text: "IDLE", foreground: DemoStyle.slate, background: DemoStyle.chipFill)
        DemoStyle.applyLabel(countLabel, style: .caption1, color: DemoStyle.slate)
        countLabel.text = "0 peripherals"

        scanButton.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(140)
        }
        let statusRow = UIStackView(arrangedSubviews: [scanStateLabel, UIView(), countLabel])
        statusRow.axis = .horizontal
        statusRow.alignment = .center
        let scanRow = UIStackView(arrangedSubviews: [scanButton, scanSpinner])
        scanRow.axis = .horizontal
        scanRow.spacing = 12
        scanRow.alignment = .center
        let column = UIStackView(arrangedSubviews: [statusRow, filterStack, uuidHintLabel, filterToggleButton, scanRow])
        column.axis = .vertical
        column.spacing = 8
        column.alignment = .center
        headerView.addSubview(column)
        column.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-12)
        }
        filterStack.snp.makeConstraints { make in
            make.width.equalTo(column)
        }
        statusRow.snp.makeConstraints { make in
            make.width.equalTo(column)
        }
        uuidHintLabel.snp.makeConstraints { make in
            make.width.equalTo(column)
        }
        applyHeader(expanded: false)
    }

    private func configureField(_ field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.font = DemoStyle.font(.subheadline)
        field.adjustsFontForContentSizeCategory = true
        field.borderStyle = .roundedRect
        field.backgroundColor = .systemBackground
        field.textColor = .label
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.clearButtonMode = .whileEditing
    }

    private func applyHeader(expanded: Bool) {
        filtersExpanded = expanded
        filterStack.isHidden = !expanded
        if !expanded {
            uuidHintLabel.isHidden = true
        } else {
            refreshUUIDHint()
        }
        filterToggleButton.setTitle(expanded ? "Collapse scanning settings" : "Expand scanning settings", for: .normal)
        let width = tableView.bounds.width > 0 ? tableView.bounds.width : UIScreen.main.bounds.width
        headerView.frame = CGRect(x: 0, y: 0, width: width, height: 1)
        let height = headerView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        headerView.frame = CGRect(x: 0, y: 0, width: width, height: max(height, 1))
        tableView.tableHeaderView = headerView
    }

    @objc private func uuidFieldChanged() {
        refreshUUIDHint()
    }

    @objc private func nameOrIdentifierFilterChanged() {
        applyNameIdentifierFilters()
    }

    /// Drop scanned rows that no longer match Name/ID filters; keep connecting/connected.
    private func applyNameIdentifierFilters() {
        let nameFilter = nameField.text ?? ""
        let identifierFilter = identifierField.text ?? ""
        let before = devices.count
        devices.removeAll { device in
            guard device.state == .scanned else { return false }
            return !DemoScanRules.passesFilters(
                name: device.displayName,
                identifier: device.identifier,
                nameFilter: nameFilter,
                identifierFilter: identifierFilter
            )
        }
        if devices.count != before {
            refreshList()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        let title = DemoStyle.buttonTitle(scanButton, fallback: "Start Scan")
        DemoStyle.applyFilled(scanButton, title: title, color: DemoStyle.primaryFill, titleColor: DemoStyle.onPrimaryFill)
    }

    private func refreshUUIDHint() {
        let invalid = DemoScanRules.invalidUUIDTokens(from: uuidField.text ?? "")
        guard filtersExpanded, !invalid.isEmpty else {
            uuidHintLabel.isHidden = true
            return
        }
        uuidHintLabel.isHidden = false
        if DemoScanRules.usesDefaultServiceUUIDs(from: uuidField.text ?? "") {
            uuidHintLabel.text = "Invalid Service UUID: \(invalid.joined(separator: ", ")). Using default services \(DemoScanRules.defaultServiceUUIDStrings.joined(separator: ", "))."
        } else {
            uuidHintLabel.text = "Invalid Service UUID ignored: \(invalid.joined(separator: ", "))"
        }
    }

    private func startCentral() {
        let states = central.observeState()
        central.start(restoreIdentifier: "BZCentralManagerRestorationIdentifier", showPowerAlert: true)
        stateTask = Task { @MainActor in
            for await state in states {
                if state == .poweredOff {
                    self.stopScan()
                    DemoFeedback.show(message: "Bluetooth is off", in: self.view)
                } else if state == .unauthorized {
                    DemoFeedback.show(message: "Bluetooth permission denied", in: self.view)
                }
            }
        }
    }

    @objc private func toggleFilters() {
        view.endEditing(true)
        applyHeader(expanded: !filtersExpanded)
    }

    @objc private func scanButtonTapped() {
        view.endEditing(true)
        if isScanning {
            stopScan()
        } else {
            startScan()
        }
    }

    private func startScan() {
        refreshUUIDHint()
        devices.removeAll { $0.state == .scanned }
        isScanning = true
        DemoStyle.applyFilled(scanButton, title: "Stop Scan", color: DemoStyle.primaryFill, titleColor: DemoStyle.onPrimaryFill)
        scanSpinner.startAnimating()
        refreshList()
        let advertisements = central.scan(services: scanServiceUUIDs(), allowDuplicates: true)
        scanTask = Task { @MainActor in
            for await advertisement in advertisements {
                self.upsert(advertisement)
            }
        }
    }

    private func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        central.stopScan()
        isScanning = false
        DemoStyle.applyFilled(scanButton, title: "Start Scan", color: DemoStyle.primaryFill, titleColor: DemoStyle.onPrimaryFill)
        scanSpinner.stopAnimating()
        refreshList()
    }

    private func scanServiceUUIDs() -> [CBUUID] {
        DemoScanRules.serviceUUIDs(from: uuidField.text ?? "")
    }

    private func refillConnectedDevices() {
        guard central.isPoweredOn else { return }
        let connected = central.retrieveConnectedPeripherals(services: scanServiceUUIDs())
        var changed = false
        for peripheral in connected where peripheral.isConnected {
            if let existing = devices.first(where: { $0.identifier == peripheral.uuidString }) {
                if existing.state != .connected {
                    existing.state = .connected
                    changed = true
                }
            } else {
                let device = DemoDevice(peripheral: peripheral, displayName: peripheral.name ?? "Unknown")
                device.state = .connected
                devices.insert(device, at: 0)
                changed = true
            }
        }
        if changed {
            refreshList()
        }
    }

    private func upsert(_ advertisement: BLEAdvertisement) {
        let peripheral = advertisement.peripheral
        let identifier = peripheral.uuidString
        let incomingName = preferredName(advertisement)
        if let row = devices.firstIndex(where: { $0.identifier == identifier }) {
            let existing = devices[row]
            if incomingName != "Unknown" {
                existing.displayName = incomingName
            }
            existing.advertisementData = advertisement.advertisementData
            existing.peripheral.rssi = advertisement.rssi ?? existing.peripheral.rssi
            if existing.state == .scanned,
               !DemoScanRules.passesFilters(
                   name: existing.displayName,
                   identifier: existing.identifier,
                   nameFilter: nameField.text ?? "",
                   identifierFilter: identifierField.text ?? ""
               ) {
                devices.remove(at: row)
                refreshList()
                return
            }
            tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
            return
        }
        guard DemoScanRules.passesFilters(name: incomingName, identifier: identifier, nameFilter: nameField.text ?? "", identifierFilter: identifierField.text ?? "") else { return }
        peripheral.rssi = advertisement.rssi
        devices.append(DemoDevice(peripheral: peripheral, displayName: incomingName, advertisementData: advertisement.advertisementData))
        refreshList()
    }

    private func preferredName(_ advertisement: BLEAdvertisement) -> String {
        if let localName = advertisement.advertisementData[CBAdvertisementDataLocalNameKey] as? String, !localName.isEmpty {
            return localName
        }
        if let name = advertisement.peripheral.name, !name.isEmpty {
            return name
        }
        return "Unknown"
    }

    @objc private func sortDevices() {
        devices.sort { ($0.peripheral.rssi?.intValue ?? Int.min) > ($1.peripheral.rssi?.intValue ?? Int.min) }
        refreshList()
    }

    private func connect(_ device: DemoDevice) {
        guard device.state == .scanned else { return }
        device.state = .connecting
        refreshList()
        stopScan()
        refreshList()
        Task { @MainActor in
            do {
                try await self.central.connect(device.peripheral)
                try await device.peripheral.discoverServices()
                device.state = .connected
            } catch {
                device.state = .scanned
                DemoFeedback.show(message: "Connection failed: \(error.localizedDescription)", in: self.view)
            }
            self.refreshList()
        }
    }

    private func disconnect(_ device: DemoDevice) {
        guard device.state == .connected else { return }
        Task { @MainActor in
            await self.central.disconnect(device.peripheral)
            device.state = .scanned
            self.refreshList()
        }
    }

    private func enter(_ device: DemoDevice) {
        guard device.state == .connected, device.peripheral.isConnected else { return }
        let controller = BZOperationViewController()
        controller.peripheral = device.peripheral
        controller.deviceName = device.displayName
        controller.advertisementData = device.advertisementData
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func deviceDisconnected(_ notification: Notification) {
        guard let identifier = notification.object as? String,
              let device = devices.first(where: { $0.identifier == identifier }) else {
            return
        }
        if device.state == .connected {
            device.state = .scanned
            refreshList()
            DemoFeedback.show(message: "Device disconnected", in: view)
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        devices.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! DemoDeviceCell
        let device = devices[indexPath.row]
        cell.update(device)
        cell.onConnect = { [weak self] in self?.connect(device) }
        cell.onDisconnect = { [weak self] in self?.disconnect(device) }
        cell.onEnter = { [weak self] in self?.enter(device) }
        return cell
    }
}
