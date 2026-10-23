import CoreBluetooth
import Flip_BLE
import SnapKit
import UIKit

private final class CharacteristicCell: UITableViewCell {
    private let uuidLabel = UILabel()
    private let badgeStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        backgroundColor = DemoStyle.card
        DemoStyle.applyIdentifier(uuidLabel)
        badgeStack.axis = .horizontal
        badgeStack.spacing = 6
        badgeStack.alignment = .center
        let stack = UIStackView(arrangedSubviews: [uuidLabel, badgeStack])
        stack.axis = .vertical
        stack.spacing = 6
        stack.alignment = .leading
        contentView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().offset(-8)
            make.top.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-10)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(_ characteristic: CBCharacteristic) {
        uuidLabel.text = characteristic.uuid.uuidString
        badgeStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let actions = DemoGATTAction.actions(for: characteristic)
        badgeStack.isHidden = actions.isEmpty
        for action in actions {
            let colors = DemoBadge.colors(for: action)
            let badge = DemoChipLabel()
            badge.apply(text: action.badgeTitle, foreground: colors.foreground, background: colors.background)
            badgeStack.addArrangedSubview(badge)
        }
    }
}

class BZCharacteristicViewController: UITableViewController {

    var peripheral: BLEPeripheral?
    var service: CBService?

    private let cellId = "CharacteristicCell"
    private let connectionWatch = DemoConnectionWatch()

    private var characteristics: [CBCharacteristic] {
        service?.characteristics ?? []
    }

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Characteristics"
        view.backgroundColor = DemoStyle.canvas
        tableView.backgroundColor = DemoStyle.canvas
        tableView.register(CharacteristicCell.self, forCellReuseIdentifier: cellId)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        setupHeader()
        refreshEmptyState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
        refreshEmptyState()
        connectionWatch.start(peripheral: peripheral, navigationController: navigationController)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        connectionWatch.stop()
    }

    private func setupHeader() {
        guard let service = service else { return }
        let label = UILabel()
        DemoStyle.applyLabel(label, style: .caption1, color: .secondaryLabel)
        label.text = "Service \(service.uuid.uuidString)"
        label.numberOfLines = 0
        let header = UIView()
        header.backgroundColor = .clear
        header.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16))
        }
        let width = UIScreen.main.bounds.width
        header.frame = CGRect(x: 0, y: 0, width: width, height: 1)
        let height = header.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        header.frame = CGRect(x: 0, y: 0, width: width, height: max(height, 36))
        tableView.tableHeaderView = header
    }

    private func refreshEmptyState() {
        DemoStyle.refreshEmptyState(for: tableView, rowCount: characteristics.count, text: "No characteristics found")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        characteristics.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! CharacteristicCell
        cell.update(characteristics[indexPath.row])
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let peripheral = peripheral else { return }
        let controller = BZPropertyListViewController()
        controller.peripheral = peripheral
        controller.characteristic = characteristics[indexPath.row]
        navigationController?.pushViewController(controller, animated: true)
    }
}
