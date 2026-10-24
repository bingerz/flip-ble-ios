import CoreBluetooth
import Flip_BLE
import SnapKit
import UIKit

private final class ServiceCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let uuidLabel = UILabel()
    private let detailLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        backgroundColor = DemoStyle.card
        DemoStyle.applyLabel(titleLabel, style: .headline)
        DemoStyle.applyIdentifier(uuidLabel, color: .secondaryLabel)
        DemoStyle.applyLabel(detailLabel, style: .caption1, color: .tertiaryLabel)
        let stack = UIStackView(arrangedSubviews: [titleLabel, uuidLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 4
        contentView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview().offset(10)
            make.bottom.lessThanOrEqualToSuperview().offset(-10)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(_ service: CBService) {
        let count = service.characteristics?.count ?? 0
        titleLabel.text = "Service (\(count))"
        uuidLabel.text = service.uuid.uuidString
        detailLabel.text = service.isPrimary ? "Primary" : "Secondary"
    }
}

class BZOperationViewController: UITableViewController {

    var peripheral: BLEPeripheral?
    var deviceName: String?
    var advertisementData: [String: Any] = [:]

    private let cellId = "ServiceCell"
    private let connectionWatch = DemoConnectionWatch()
    private let retryItem = UIBarButtonItem(title: "Retry Discover", style: .plain, target: nil, action: nil)
    private let retrySpinner = UIActivityIndicatorView(style: .medium)

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Services"
        view.backgroundColor = DemoStyle.canvas
        tableView.backgroundColor = DemoStyle.canvas
        tableView.register(ServiceCell.self, forCellReuseIdentifier: cellId)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 78
        retryItem.target = self
        retryItem.action = #selector(retryDiscover)
        navigationItem.rightBarButtonItem = retryItem
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
        guard let peripheral = peripheral else { return }
        let nameLabel = UILabel()
        DemoStyle.applyLabel(nameLabel, style: .headline)
        nameLabel.text = deviceName ?? peripheral.name ?? "Unknown"
        nameLabel.numberOfLines = 0
        let idLabel = UILabel()
        DemoStyle.applyLabel(idLabel, style: .caption1, color: .secondaryLabel)
        idLabel.text = peripheral.uuidString
        idLabel.numberOfLines = 0
        let advLabel = UILabel()
        DemoStyle.applyLabel(advLabel, style: .caption1, color: .tertiaryLabel)
        advLabel.text = DemoAdvertisementSummary.text(from: advertisementData)
        advLabel.numberOfLines = 0
        advLabel.isHidden = advLabel.text?.isEmpty ?? true

        let stack = UIStackView(arrangedSubviews: [nameLabel, idLabel, advLabel])
        stack.axis = .vertical
        stack.spacing = 4
        let card = UIView()
        card.backgroundColor = DemoStyle.card
        card.layer.cornerRadius = 12
        card.layer.borderWidth = 1
        DemoStyle.refreshBorder(of: card.layer, color: DemoStyle.hairline, traits: traitCollection)
        let header = UIView()
        header.backgroundColor = .clear
        header.addSubview(card)
        card.addSubview(stack)
        card.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 4, right: 16))
        }
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        }
        let width = UIScreen.main.bounds.width
        header.frame = CGRect(x: 0, y: 0, width: width, height: 1)
        let height = header.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        header.frame = CGRect(x: 0, y: 0, width: width, height: max(height, 44))
        tableView.tableHeaderView = header
    }

    private func discoverMessage(for error: Error) -> String {
        guard let bleError = error as? BLEError else { return error.localizedDescription }
        switch bleError {
        case .invalidOperation(let message):
            return message
        case .disconnected:
            return "Device is disconnected"
        case .gatt:
            return "GATT error"
        case .scanFailed:
            return "Scan failed"
        case .underlying(let underlying):
            return underlying.localizedDescription
        }
    }

    private func refreshEmptyState() {
        DemoStyle.refreshEmptyState(for: tableView, rowCount: peripheral?.services.count ?? 0, text: "No services discovered\nTap Retry Discover to try again")
    }

    @objc private func retryDiscover() {
        guard let peripheral = peripheral else { return }
        retryItem.isEnabled = false
        let spinnerItem = UIBarButtonItem(customView: retrySpinner)
        navigationItem.rightBarButtonItem = spinnerItem
        retrySpinner.startAnimating()
        Task { @MainActor in
            defer {
                self.retrySpinner.stopAnimating()
                self.navigationItem.rightBarButtonItem = self.retryItem
                self.retryItem.isEnabled = true
                self.refreshEmptyState()
            }
            do {
                try await peripheral.discoverIfIdle()
                self.tableView.reloadData()
            } catch {
                let alert = UIAlertController(title: "Discover failed", message: self.discoverMessage(for: error), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        peripheral?.services.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! ServiceCell
        if let service = peripheral?.services[indexPath.row] {
            cell.update(service)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let peripheral = peripheral, indexPath.row < peripheral.services.count else { return }
        let controller = BZCharacteristicViewController()
        controller.peripheral = peripheral
        controller.service = peripheral.services[indexPath.row]
        navigationController?.pushViewController(controller, animated: true)
    }
}
