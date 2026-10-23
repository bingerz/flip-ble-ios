import CoreBluetooth
import Flip_BLE
import SnapKit
import UIKit

private final class PropertyCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let iconView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        backgroundColor = DemoStyle.card
        DemoStyle.applyLabel(titleLabel, style: .headline)
        iconView.tintColor = DemoStyle.primaryFill
        iconView.contentMode = .scaleAspectFit
        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(22)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.trailing.lessThanOrEqualToSuperview().offset(-8)
            make.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(_ action: DemoGATTAction) {
        titleLabel.text = action.title
        let colors = DemoBadge.colors(for: action)
        titleLabel.textColor = colors.foreground
        iconView.tintColor = colors.foreground
        iconView.image = UIImage(systemName: action.systemImageName)
        accessibilityLabel = action.title
    }
}

class BZPropertyListViewController: UITableViewController {

    var peripheral: BLEPeripheral?
    var characteristic: CBCharacteristic?

    private let cellId = "PropertyCell"
    private let connectionWatch = DemoConnectionWatch()
    private var actions: [DemoGATTAction] = []

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Properties"
        view.backgroundColor = DemoStyle.canvas
        tableView.backgroundColor = DemoStyle.canvas
        tableView.register(PropertyCell.self, forCellReuseIdentifier: cellId)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        if let characteristic = characteristic {
            actions = DemoGATTAction.actions(for: characteristic)
        }
        DemoStyle.refreshEmptyState(for: tableView, rowCount: actions.count, text: "No properties")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        connectionWatch.start(peripheral: peripheral, navigationController: navigationController)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        connectionWatch.stop()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        actions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! PropertyCell
        cell.update(actions[indexPath.row])
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let peripheral = peripheral, let characteristic = characteristic else { return }
        let controller = BZConsoleViewController()
        controller.peripheral = peripheral
        controller.characteristic = characteristic
        controller.action = actions[indexPath.row]
        navigationController?.pushViewController(controller, animated: true)
    }
}
