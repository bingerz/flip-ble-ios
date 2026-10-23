import CoreBluetooth
import Flip_BLE
import UIKit

enum DemoGATTAction {
    case read
    case write
    case writeWithoutResponse
    case notify
    case indicate

    var title: String {
        switch self {
        case .read:
            return "Read"
        case .write:
            return "Write"
        case .writeWithoutResponse:
            return "Write No Response"
        case .notify:
            return "Notify"
        case .indicate:
            return "Indicate"
        }
    }

    var systemImageName: String {
        switch self {
        case .read:
            return "arrow.down.doc"
        case .write:
            return "pencil"
        case .writeWithoutResponse:
            return "pencil.slash"
        case .notify:
            return "bell"
        case .indicate:
            return "bell.badge"
        }
    }

    var badgeTitle: String {
        switch self {
        case .read:
            return "READ"
        case .write:
            return "WRITE"
        case .writeWithoutResponse:
            return "WRITE NR"
        case .notify:
            return "NOTIFY"
        case .indicate:
            return "INDICATE"
        }
    }

    static func actions(for properties: CBCharacteristicProperties) -> [DemoGATTAction] {
        var actions: [DemoGATTAction] = []
        if properties.contains(.read) {
            actions.append(.read)
        }
        if properties.contains(.write) {
            actions.append(.write)
        }
        if properties.contains(.writeWithoutResponse) {
            actions.append(.writeWithoutResponse)
        }
        if properties.contains(.notify) {
            actions.append(.notify)
        }
        if properties.contains(.indicate) {
            actions.append(.indicate)
        }
        return actions
    }

    static func actions(for characteristic: CBCharacteristic) -> [DemoGATTAction] {
        actions(for: characteristic.properties)
    }

    static func summary(for properties: CBCharacteristicProperties) -> String {
        let titles = actions(for: properties).map(\.title)
        return titles.isEmpty ? "No properties" : titles.joined(separator: " ")
    }

    static func summary(for characteristic: CBCharacteristic) -> String {
        summary(for: characteristic.properties)
    }
}

enum DemoScanRules {
    static let defaultServiceUUIDStrings = ["1803", "0900", "FD44", "FE2C", "FEAA"]

    static func commaTokens(_ text: String) -> [String] {
        text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    static func parseServiceUUID(_ raw: String) -> CBUUID? {
        let hex = raw.replacingOccurrences(of: "-", with: "")
        guard hex.range(of: "^[0-9a-fA-F]+$", options: .regularExpression) != nil else {
            return nil
        }
        guard [4, 8, 32].contains(hex.count) else {
            return nil
        }
        return CBUUID(string: raw)
    }

    static func serviceUUIDs(from text: String) -> [CBUUID] {
        let parsed = commaTokens(text).compactMap(parseServiceUUID)
        if parsed.isEmpty {
            return defaultServiceUUIDStrings.map { CBUUID(string: $0) }
        }
        return parsed
    }

    static func invalidUUIDTokens(from text: String) -> [String] {
        commaTokens(text).filter { parseServiceUUID($0) == nil }
    }

    static func usesDefaultServiceUUIDs(from text: String) -> Bool {
        commaTokens(text).compactMap(parseServiceUUID).isEmpty
    }

    static func passesFilters(name: String, identifier: String, nameFilter: String, identifierFilter: String) -> Bool {
        let names = commaTokens(nameFilter)
        if !names.isEmpty && !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            return false
        }
        let identifiers = commaTokens(identifierFilter)
        if !identifiers.isEmpty && !identifiers.contains(where: { $0.caseInsensitiveCompare(identifier) == .orderedSame }) {
            return false
        }
        return true
    }
}

enum DemoHex {
    static func string(from data: Data) -> String {
        if data.isEmpty {
            return "empty"
        }
        return data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    static func data(from text: String) -> Data? {
        let cleaned = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "0x", with: "", options: .caseInsensitive)
        guard !cleaned.isEmpty, cleaned.count % 2 == 0 else {
            return nil
        }
        var data = Data()
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = next
        }
        return data
    }
}

enum DemoAdvertisementSummary {
    static func lines(from advertisementData: [String: Any]) -> [String] {
        var lines: [String] = []
        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data], !serviceData.isEmpty {
            for uuid in serviceData.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
                if let data = serviceData[uuid] {
                    lines.append("Service Data \(uuid.uuidString): \(DemoHex.string(from: data))")
                }
            }
        }
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data, !manufacturerData.isEmpty {
            if manufacturerData.count >= 2 {
                let companyID = UInt16(manufacturerData[0]) | (UInt16(manufacturerData[1]) << 8)
                let rest = manufacturerData.dropFirst(2)
                let suffix = rest.isEmpty ? "" : ": \(DemoHex.string(from: Data(rest)))"
                lines.append(String(format: "Manufacturer %04X%@", companyID, suffix))
            } else {
                lines.append("Manufacturer Data: \(DemoHex.string(from: manufacturerData))")
            }
        }
        if let txPower = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber {
            lines.append("Tx Power: \(txPower.intValue) dBm")
        }
        if let connectable = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber {
            lines.append(connectable.boolValue ? "Connectable" : "Not connectable")
        }
        return lines
    }

    static func text(from advertisementData: [String: Any]) -> String {
        lines(from: advertisementData).joined(separator: "\n")
    }

    /// Short pills for the scan card. Long payloads stay on the service page.
    static func chips(from advertisementData: [String: Any]) -> [String] {
        var chips: [String] = []
        if let txPower = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber {
            chips.append("TX: \(txPower.intValue) dBm")
        }
        if let connectable = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber {
            chips.append(connectable.boolValue ? "Connectable" : "Non-conn")
        }
        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
           let uuid = serviceData.keys.sorted(by: { $0.uuidString < $1.uuidString }).first {
            chips.append(clipped(uuid.uuidString))
        }
        return chips
    }

    private static func clipped(_ text: String, limit: Int = 18) -> String {
        guard text.count > limit else { return text }
        let end = text.index(text.startIndex, offsetBy: limit - 1)
        return String(text[..<end]) + "…"
    }
}

final class DemoConsoleStore {
    static let shared = DemoConsoleStore()

    struct Entry {
        var text: String = ""
        var isOn: Bool = false
    }

    private var entries: [String: Entry] = [:]

    static func key(peripheralID: String, characteristicUUID: String, action: DemoGATTAction) -> String {
        "\(peripheralID)|\(characteristicUUID)|\(action.title)"
    }

    func entry(for key: String) -> Entry {
        entries[key] ?? Entry()
    }

    func save(text: String, isOn: Bool, for key: String) {
        entries[key] = Entry(text: text, isOn: isOn)
    }

    func clear(for key: String) {
        entries[key] = Entry()
    }

    func removeAll() {
        entries.removeAll()
    }
}

extension Notification.Name {
    static let demoPeripheralDisconnected = Notification.Name("demoPeripheralDisconnected")
}

final class DemoConnectionWatch {
    private var task: Task<Void, Never>?

    func start(peripheral: BLEPeripheral?, navigationController: UINavigationController?) {
        stop()
        guard let peripheral = peripheral else { return }
        task = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 400_000_000)
                if Task.isCancelled {
                    return
                }
                if !peripheral.isConnected {
                    NotificationCenter.default.post(name: .demoPeripheralDisconnected, object: peripheral.uuidString)
                    navigationController?.popToRootViewController(animated: true)
                    return
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}

enum DemoStyle {
    static let accent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIUtils.color(red: 64, green: 224, blue: 190, alpha: 1.0)
            : UIUtils.color(red: 0, green: 166, blue: 132, alpha: 1.0)
    }

    /// Dark text on the bright dark-mode accent; white on the deeper light-mode accent.
    static let onAccent = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.08, alpha: 1) : .white
    }

    /// Pale cobalt in dark mode, system blue in light mode.
    static let primaryFill = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xAD / 255, green: 0xC6 / 255, blue: 1, alpha: 1)
            : UIColor(red: 0, green: 0x7A / 255, blue: 1, alpha: 1)
    }

    static let onPrimaryFill = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0, green: 0x2E / 255, blue: 0x69 / 255, alpha: 1)
            : .white
    }

    static let canvas = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x0A / 255, green: 0x0D / 255, blue: 0x12 / 255, alpha: 1)
            : .systemGroupedBackground
    }

    static let card = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x12 / 255, green: 0x17 / 255, blue: 0x21 / 255, alpha: 1)
            : .secondarySystemGroupedBackground
    }

    static let chipFill = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x1A / 255, green: 0x21 / 255, blue: 0x2E / 255, alpha: 1)
            : .tertiarySystemFill
    }

    static let slate = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x8E / 255, green: 0x8E / 255, blue: 0x93 / 255, alpha: 1)
            : .secondaryLabel
    }

    static let amber = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1, green: 0x9F / 255, blue: 0x0A / 255, alpha: 1)
            : .systemOrange
    }

    static let hairline = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.08) : .separator
    }

    static let barTrack = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.12) : .tertiarySystemFill
    }

    static func font(_ style: UIFont.TextStyle, weight: UIFont.Weight? = nil) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        guard let weight = weight else { return base }
        let descriptor = base.fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: base.pointSize)
    }

    static func applyLabel(_ label: UILabel, style: UIFont.TextStyle, color: UIColor = .label, weight: UIFont.Weight? = nil) {
        label.font = font(style, weight: weight)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
    }

    /// One-line monospaced identifier. Long UUIDs truncate in the middle so both ends stay visible.
    static func applyIdentifier(_ label: UILabel, color: UIColor = .label) {
        let base = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        label.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: base)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingMiddle
    }

    static func applyOutline(_ button: UIButton, title: String, color: UIColor) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = font(.subheadline, weight: .medium)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.setTitleColor(color, for: .normal)
        button.setTitleColor(color.withAlphaComponent(0.7), for: .highlighted)
        button.setTitleColor(.tertiaryLabel, for: .disabled)
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 1
        button.clipsToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        refreshBorder(of: button.layer, color: color, traits: button.traitCollection)
    }

    static func applyFilled(_ button: UIButton, title: String, color: UIColor, titleColor: UIColor = onAccent) {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = color
        config.baseForegroundColor = titleColor
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
            return outgoing
        }
        button.configuration = config
    }

    static func buttonTitle(_ button: UIButton, fallback: String) -> String {
        button.configuration?.title ?? button.title(for: .normal) ?? fallback
    }

    /// `CALayer.borderColor` is a resolved `CGColor`; re-apply after appearance changes.
    static func refreshBorder(of layer: CALayer, color: UIColor, traits: UITraitCollection) {
        layer.borderColor = color.resolvedColor(with: traits).cgColor
    }

    static func makeEmptyLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        applyLabel(label, style: .body, color: .secondaryLabel)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }

    static func refreshEmptyState(for tableView: UITableView, rowCount: Int, text: String) {
        tableView.backgroundView = rowCount == 0 ? makeEmptyLabel(text) : nil
    }
}

enum DemoFeedback {
    private static let toastTag = 0x464C_5042 // "FLPB"

    @MainActor
    static func show(message: String, in view: UIView) {
        view.viewWithTag(toastTag)?.removeFromSuperview()
        let label = UILabel()
        label.tag = toastTag
        label.text = message
        DemoStyle.applyLabel(label, style: .footnote, color: .white)
        label.backgroundColor = UIColor.label.withAlphaComponent(0.88)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.alpha = 0
        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            label.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])
        UIView.animate(withDuration: 0.2, animations: { label.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.3, delay: 2.2, options: [], animations: { label.alpha = 0 }) { _ in
                label.removeFromSuperview()
            }
        }
    }
}

enum DemoSignal {
    /// 4 excellent, 3 good, 2 weak, 1 marginal. Matches the design meter's dBm bands.
    static func level(for rssi: Int) -> Int {
        if rssi >= -60 { return 4 }
        if rssi >= -75 { return 3 }
        if rssi >= -85 { return 2 }
        return 1
    }

    static func color(for rssi: Int) -> UIColor {
        switch level(for: rssi) {
        case 3, 4:
            return DemoStyle.accent
        case 2:
            return DemoStyle.amber
        default:
            return DemoStyle.slate
        }
    }
}

enum DemoBadge {
    static func colors(for action: DemoGATTAction) -> (foreground: UIColor, background: UIColor) {
        switch action {
        case .read:
            return (UIColor(red: 0x38 / 255, green: 0x9B / 255, blue: 1, alpha: 1),
                    UIColor(red: 0, green: 0x7A / 255, blue: 1, alpha: 0.14))
        case .write:
            return (UIColor(red: 1, green: 0xB3 / 255, blue: 0x40 / 255, alpha: 1),
                    UIColor(red: 1, green: 0x9F / 255, blue: 0x0A / 255, alpha: 0.14))
        case .writeWithoutResponse:
            return (UIColor(red: 1, green: 0xB3 / 255, blue: 0x40 / 255, alpha: 1),
                    UIColor(red: 1, green: 0x9F / 255, blue: 0x0A / 255, alpha: 0.14))
        case .notify:
            return (UIColor(red: 0x2B / 255, green: 0xE3 / 255, blue: 0xA3 / 255, alpha: 1),
                    UIColor(red: 0, green: 0xD6 / 255, blue: 0x8F / 255, alpha: 0.14))
        case .indicate:
            return (UIColor(red: 0xD3 / 255, green: 0x7F / 255, blue: 0xF6 / 255, alpha: 1),
                    UIColor(red: 0xBF / 255, green: 0x5A / 255, blue: 0xF2 / 255, alpha: 0.14))
        }
    }
}

final class DemoChipLabel: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        font = UIFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        textAlignment = .center
        layer.cornerRadius = 6
        clipsToBounds = true
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 12, height: max(size.height + 6, 22))
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.insetBy(dx: 6, dy: 3))
    }

    func apply(text: String, foreground: UIColor, background: UIColor) {
        self.text = text
        textColor = foreground
        backgroundColor = background
    }
}

final class DemoSignalBars: UIView {
    private let bars: [UIView]

    override init(frame: CGRect) {
        let heights: [CGFloat] = [6, 9, 12, 15]
        bars = heights.map { height in
            let bar = UIView()
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.layer.cornerRadius = 1
            bar.widthAnchor.constraint(equalToConstant: 3).isActive = true
            bar.heightAnchor.constraint(equalToConstant: height).isActive = true
            return bar
        }
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: bars)
        stack.axis = .horizontal
        stack.alignment = .bottom
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 15)
        ])
        apply(rssi: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(rssi: Int?) {
        let level = rssi.map(DemoSignal.level) ?? 0
        let color = rssi.map(DemoSignal.color) ?? DemoStyle.slate
        for (index, bar) in bars.enumerated() {
            bar.backgroundColor = index < level ? color : DemoStyle.barTrack
        }
    }
}
