//
//  BZHomeViewController.swift
//  Flip-BLE_Example
//
//  Created by Hanson on 2022/8/19.
//  Copyright © 2022 hanbing0604@aliyun.com. All rights reserved.
//

import Foundation
import UIKit
import SnapKit
import CoreBluetooth

enum BZPeripheralCellState {
    case scanned
    case connecting
    case connected
}

class BZPeripheralCell: UITableViewCell {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        initView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        peripheral = nil
    }

    var peripheral: BZPeripheral? {
        didSet {
            updateDeviceViewState()
        }
    }

    var cellState: BZPeripheralCellState = .scanned {
        didSet {
            updateDeviceViewState()
        }
    }
    
    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .black
        label.minimumScaleFactor = 0.8
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .gray
        label.minimumScaleFactor = 0.8
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        return view
    }()

    let funcButton: UIButton = {
        let button = UIButton()
        button.setTitle("Connect", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.setTitleColor(UIUtils.color(red: 48, green: 206, blue: 170, alpha: 1.0), for: .normal)
        button.setTitleColor(UIUtils.color(red: 43, green: 186, blue: 152, alpha: 1.0), for: .highlighted)
        button.titleLabel?.minimumScaleFactor = 0.5
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.setBackgroundImage(UIUtils.createImageWithColor(UIUtils.color(red: 255, green: 255, blue: 255, alpha: 1.0)), for: .normal)
        button.setBackgroundImage(UIUtils.createImageWithColor(UIUtils.color(red: 242, green: 255, blue: 252, alpha: 1.0)), for: .highlighted)
        button.clipsToBounds = true
        button.layer.cornerRadius = 18
        button.layer.borderWidth = 1
        button.layer.borderColor = UIUtils.color(red: 48, green: 206, blue: 170, alpha: 1.0).cgColor
        button.isUserInteractionEnabled = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let disconnectButton: UIButton = {
        let button = UIButton()
        button.setTitle("Disconnect", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.setTitleColor(UIColor.red, for: .normal)
        button.setTitleColor(UIColor.red.withAlphaComponent(0.7), for: .highlighted)
        button.titleLabel?.minimumScaleFactor = 0.5
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.setBackgroundImage(UIUtils.createImageWithColor(UIColor.white), for: .normal)
        button.setBackgroundImage(UIUtils.createImageWithColor(UIColor.red.withAlphaComponent(0.1)), for: .highlighted)
        button.clipsToBounds = true
        button.layer.cornerRadius = 18
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.red.cgColor
        button.isUserInteractionEnabled = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()

    let loadingIndicator: UIActivityIndicatorView = {
        if #available(iOS 13.0, *) {
            let indicator = UIActivityIndicatorView(activityIndicatorStyle: .medium)
            indicator.hidesWhenStopped = true
            indicator.translatesAutoresizingMaskIntoConstraints = false
            return indicator
        } else {
            let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
            indicator.hidesWhenStopped = true
            indicator.translatesAutoresizingMaskIntoConstraints = false
            return indicator
        }
    }()
    
    fileprivate func initView() {
        self.containerView.addSubview(nameLabel)
        self.containerView.addSubview(statusLabel)
        self.contentView.addSubview(containerView)
        self.contentView.addSubview(funcButton)
        self.contentView.addSubview(disconnectButton)
        self.contentView.addSubview(loadingIndicator)

        containerView.snp.makeConstraints { make in
            make.height.equalTo(48)
            make.leading.equalToSuperview().offset(20)
            make.trailing.lessThanOrEqualToSuperview().offset(-170)
            make.centerY.equalToSuperview()
        }

        nameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
        }

        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
        }

        // Disconnect button (left side)
        disconnectButton.snp.makeConstraints { make in
            make.width.equalTo(70)
            make.height.equalTo(36)
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
        }

        // Detail/Connect button (right side)
        funcButton.snp.makeConstraints { make in
            make.width.equalTo(70)
            make.height.equalTo(36)
            make.trailing.equalTo(disconnectButton.snp.leading).offset(-6)
            make.centerY.equalToSuperview()
        }

        loadingIndicator.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
        }
    }
    
    fileprivate func updateDeviceViewState() {
        guard let peripheral = peripheral else { return }

        nameLabel.text = peripheral.name()

        switch cellState {
        case .scanned:
            statusLabel.text = "RSSI: \(peripheral.scannedRSSINumber.intValue)"
            funcButton.isHidden = false
            disconnectButton.isHidden = true
            loadingIndicator.stopAnimating()
            funcButton.setTitle("Connect", for: .normal)
            funcButton.isEnabled = true
            // Connect 按钮保持原样
            funcButton.snp.remakeConstraints { make in
                make.width.equalTo(100)
                make.height.equalTo(36)
                make.trailing.equalToSuperview().offset(-40)
                make.centerY.equalToSuperview()
            }
            containerView.snp.remakeConstraints { make in
                make.height.equalTo(48)
                make.leading.equalToSuperview().offset(20)
                make.trailing.equalToSuperview().offset(-20)
                make.centerY.equalToSuperview()
            }

        case .connecting:
            statusLabel.text = "Connecting..."
            funcButton.isHidden = true
            disconnectButton.isHidden = true
            loadingIndicator.startAnimating()
            containerView.snp.remakeConstraints { make in
                make.height.equalTo(48)
                make.leading.equalToSuperview().offset(20)
                make.trailing.equalToSuperview().offset(-20)
                make.centerY.equalToSuperview()
            }

        case .connected:
            statusLabel.text = "RSSI: \(peripheral.scannedRSSINumber.intValue)"
            funcButton.isHidden = false
            disconnectButton.isHidden = false
            loadingIndicator.stopAnimating()
            funcButton.setTitle("Detail", for: .normal)
            funcButton.isEnabled = true
            // 已连接状态：两个按钮都显示
            funcButton.snp.remakeConstraints { make in
                make.width.equalTo(65)
                make.height.equalTo(36)
                make.trailing.equalTo(disconnectButton.snp.leading).offset(-6)
                make.centerY.equalToSuperview()
            }
            disconnectButton.snp.remakeConstraints { make in
                make.width.equalTo(75)
                make.height.equalTo(36)
                make.trailing.equalToSuperview().offset(-10)
                make.centerY.equalToSuperview()
            }
            containerView.snp.remakeConstraints { make in
                make.height.equalTo(48)
                make.leading.equalToSuperview().offset(20)
                make.trailing.lessThanOrEqualToSuperview().offset(-165)
                make.centerY.equalToSuperview()
            }
        }
    }
}

fileprivate extension Selector{
    static let headerBtnAction  = #selector(BZHomeViewController.headerBtnAction(_:))
}

class BZHomeViewController: UITableViewController, BZScanDelegate, BZCentralStateDelegate, BZConnectStateDelegate {
    
    private let cellId = "CellId"
    
    private let BTN_TAG_RESCAN      = 1;
    private let BTN_TAG_RETRIEVE    = 2;

    fileprivate var scannedPeripheralArray = [BZPeripheral]()
    fileprivate var connectingPeripheralArray = [BZPeripheral]()
    fileprivate var connectedPeripheralArray = [BZPeripheral]()
    
    var centralManager: BZCentralManager = BZCentralManager.default()
    
    deinit {
        
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "FlipBLE"
        setupTableView()
        setupHeaderView()
        initCentralManager()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    func setupTableView() {
        tableView.register(BZPeripheralCell.self, forCellReuseIdentifier: cellId)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        tableView.separatorStyle = .singleLine
    }
    
    func setupHeaderView() {
        var headerView: UIView?
        headerView = createHeaderView()
        if headerView != nil {
            tableView.tableHeaderView?.removeFromSuperview()
            tableView.tableHeaderView = headerView
        }
    }
    
    @IBAction func headerBtnAction(_ sender: UIButton) {
        switch sender.tag {
        case BTN_TAG_RESCAN:
            stopScanDevice()
            scannedPeripheralArray.removeAll()
            reloadTableView()
            startScanDevice()
        case BTN_TAG_RETRIEVE:
            let retrieveDeviceArray = centralManager.retrievePeripherals(["661B2DDA-C234-E43C-646F-200FDFF21499", "DBD28847-DDDC-4B45-902D-326A7E70C780"])
            if let array = retrieveDeviceArray {
                NSLog("retrievePeripherals count %d", array.count)
            }
        default:
            break
        }
    }
    
    func reloadTableView() {
        tableView.reloadData()
    }
    
    func initCentralManager() {
        let restoreIdKey = "BZCentralManagerRestorationIdentifier"
        centralManager = BZCentralManager.default()
        centralManager.startCentral(withRestoreIdKey: restoreIdKey, showPowerAlert: true)
        centralManager.scanDelegate = self
        centralManager.centralStateDelegate = self
    }
    
    func destroyCentralManager() {
        stopScanDevice()
        centralManager.destroyCentral()
    }
    
    func insertScannedDevice(_ perpheral: BZPeripheral) {
        scannedPeripheralArray.append(perpheral)
    }
    
    func removeScannedDevice(_ perpheral: BZPeripheral) {
        scannedPeripheralArray.removeAll { $0.uuidString() == perpheral.uuidString() }
    }

    func insertConnectingDevice(_ peripheral: BZPeripheral) {
        connectingPeripheralArray.append(peripheral)
    }

    func removeConnectingDevice(_ peripheral: BZPeripheral) {
        connectingPeripheralArray.removeAll { $0.uuidString() == peripheral.uuidString() }
    }

    func insertConnectedDevice(_ perpheral: BZPeripheral) {
        connectedPeripheralArray.append(perpheral)
    }

    func removeConnectedDevice(_ perpheral: BZPeripheral) {
        connectedPeripheralArray.removeAll { $0.uuidString() == perpheral.uuidString() }
    }
    
    func startScanDevice() {
        let LLServiceUUID = "1803"
        let NTServiceUUID = "0900"
        let FMNAServiceUUID = "FD44"
        let FMDNServiceUUID = "FE2C"
        let FMDNEIDServiceUUID = "FEAA"
        let scanServices = [CBUUID(string: LLServiceUUID), CBUUID(string: NTServiceUUID),
                            CBUUID(string: FMNAServiceUUID), CBUUID(string: FMDNServiceUUID),
                            CBUUID(string: FMDNEIDServiceUUID)]
        centralManager.startScan(withServices: scanServices, allowDup: false)
    }
    
    func stopScanDevice() {
        centralManager.stopScan()
    }
    
    func centralDidUpdate(_ state: CBManagerState) {
        switch (state) {
        case .poweredOff:
            NSLog("centralDidUpdateState poweredOff")
            stopScanDevice()
            break;
        case .poweredOn:
            NSLog("centralDidUpdateState poweredOn");
            startScanDevice()
            break;
        default:
            break;
        }
    }
    
    func didScanning(_ peripheral: BZPeripheral!, advData: [AnyHashable : Any]!) {
        let advDataDic: [String: Any] = advData as? [String: Any] ?? [:]
        if let localName = advDataDic[CBAdvertisementDataLocalNameKey] {
            let deviceName: NSString = NSString(string: localName as! String)
            NSLog("Scan peripheral name %@ %@", deviceName, peripheral.uuidString());
        }
        insertScannedDevice(peripheral)
        reloadTableView()
    }
    
    func didConnecting() {
        // 移动到连接中分组
        reloadTableView()
    }
    
    func didRetrieve(_ peripheral: BZPeripheral!) {
        
    }
    
    func didRestored(_ peripheral: BZPeripheral!) {
        
    }
    
    func didRetrieveConnected(_ peripheral: BZPeripheral!) {
        
    }
    
    func didConnected(_ peripheral: BZPeripheral!) {
        // 从连接中移除，添加到已连接
        removeConnectingDevice(peripheral)
        insertConnectedDevice(peripheral)

        peripheral.discoverServices { (peripheral, error) in
            // 服务发现完成
            DispatchQueue.main.async {
                self.reloadTableView()
            }
        }
    }
    
    func didConnectError(_ peripheral: BZPeripheral!, error: Error!) {
        // 从连接中移除，放回扫描列表
        removeConnectingDevice(peripheral)
        insertScannedDevice(peripheral)
        reloadTableView()
    }
    
    func didDisconnected(_ peripheral: BZPeripheral!, error: Error!) {
        removeConnectedDevice(peripheral)
        reloadTableView()
    }
    
    @objc func connectButtonClicked(sender: UIButton) {
        let peripheral = scannedPeripheralArray[sender.tag]
        peripheral.connectStateDelegate = self
        centralManager.add(peripheral)
        centralManager.connect(peripheral)

        // 添加到连接中列表，并从扫描列表移除
        removeScannedDevice(peripheral)
        insertConnectingDevice(peripheral)
        reloadTableView()
    }
    
    @objc func disconnectButtonClicked(sender: UIButton) {
        let peripheral = connectedPeripheralArray[sender.tag]
        centralManager.cancel(peripheral)
    }
    
    @objc func viewButtonClicked(sender: UIButton) {
        let peripheral = connectedPeripheralArray[sender.tag]
        self.showServiceList(peripheral)
    }
    
    func showServiceList(_ peripheral: BZPeripheral?) {
        if let peripheral = peripheral {
            let vc = BZOperationViewController()
            vc.peripheral = peripheral
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3  // Connected, Connecting, Scanned
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return connectedPeripheralArray.count
        case 1: return connectingPeripheralArray.count
        case 2: return scannedPeripheralArray.count
        default: return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 65
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Connected Device"
        case 1: return "Connecting Device"
        case 2: return "Scanned Device"
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId) as! BZPeripheralCell

        switch indexPath.section {
        case 0: // Connected
            let peripheral = connectedPeripheralArray[indexPath.row]
            cell.peripheral = peripheral
            cell.cellState = .connected
            cell.funcButton.tag = indexPath.row
            cell.funcButton.removeTarget(nil, action: nil, for: .touchUpInside)
            cell.funcButton.addTarget(self, action: #selector(viewButtonClicked(sender:)), for: .touchUpInside)
            cell.disconnectButton.tag = indexPath.row
            cell.disconnectButton.removeTarget(nil, action: nil, for: .touchUpInside)
            cell.disconnectButton.addTarget(self, action: #selector(disconnectButtonClicked(sender:)), for: .touchUpInside)

        case 1: // Connecting
            let peripheral = connectingPeripheralArray[indexPath.row]
            cell.peripheral = peripheral
            cell.cellState = .connecting

        case 2: // Scanned
            let peripheral = scannedPeripheralArray[indexPath.row]
            cell.peripheral = peripheral
            cell.cellState = .scanned
            cell.funcButton.tag = indexPath.row
            cell.funcButton.removeTarget(nil, action: nil, for: .touchUpInside)
            cell.funcButton.addTarget(self, action: #selector(connectButtonClicked(sender:)), for: .touchUpInside)

        default:
            break
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if self.tableView == tableView {
            if indexPath.section == 0 {
                let device = connectedPeripheralArray[indexPath.row]
                
            } else if indexPath.section == 1 {
                let device = scannedPeripheralArray[indexPath.row]
            }
        }
    }
    
    func createHeaderView() -> UIView {
        let lightGreen = UIUtils.color(red: 48, green: 206, blue: 170, alpha: 1.0)
        let deepGreen = UIUtils.color(red: 43, green: 186, blue: 152, alpha: 1.0)
        let headerView = UIUtils.getTableViewHeaderView(height: 112, bgColor: .white)
        
        let contentView = UIView()
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 8
        headerView.addSubview(contentView)
        contentView.snp.makeConstraints { (make) in
            make.width.equalTo(UIUtils.screenWidth() - 40)
            make.centerX.equalToSuperview()
            make.topMargin.equalTo(10)
            make.bottomMargin.equalToSuperview()
        }
        
        let reScanBtn = UIButton()
        reScanBtn.setTitle(NSLocalizedString("ReScan", comment: ""), for: .normal)
        reScanBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        reScanBtn.setTitleColor(lightGreen, for: .normal)
        reScanBtn.setTitleColor(deepGreen, for: .highlighted)
        reScanBtn.titleLabel?.minimumScaleFactor = 0.5
        reScanBtn.titleLabel?.adjustsFontSizeToFitWidth = true
        reScanBtn.setBackgroundImage(UIUtils.createImageWithColor(UIUtils.color(red: 255, green: 255, blue: 255, alpha: 0.3)), for: .normal)
        reScanBtn.setBackgroundImage(UIUtils.createImageWithColor(UIUtils.color(red: 255, green: 255, blue: 255, alpha: 0.08)), for: .highlighted)
        reScanBtn.clipsToBounds = true
        reScanBtn.layer.cornerRadius = 18
        reScanBtn.layer.borderWidth = 1
        reScanBtn.layer.borderColor = lightGreen.cgColor
        reScanBtn.addTarget(self, action: .headerBtnAction, for: .touchUpInside)
        reScanBtn.tag = BTN_TAG_RESCAN
        contentView.addSubview(reScanBtn)
        reScanBtn.snp.makeConstraints { (make) in
            make.width.equalTo(100)
            make.height.equalTo(36)
            make.leftMargin.equalTo(20)
            make.topMargin.equalTo(10)
        }
        
        let retrieveBtn = UIButton()
        retrieveBtn.setTitle(NSLocalizedString("Retrieve", comment: ""), for: .normal)
        retrieveBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        retrieveBtn.setTitleColor(lightGreen, for: .normal)
        retrieveBtn.setTitleColor(deepGreen, for: .highlighted)
        retrieveBtn.titleLabel?.minimumScaleFactor = 0.5
        retrieveBtn.titleLabel?.adjustsFontSizeToFitWidth = true
        retrieveBtn.setBackgroundImage(UIUtils.createImageWithColor(UIUtils.color(red: 255, green: 255, blue: 255, alpha: 0.3)), for: .normal)
        retrieveBtn.setBackgroundImage(UIUtils.createImageWithColor(UIUtils.color(red: 255, green: 255, blue: 255, alpha: 0.08)), for: .highlighted)
        retrieveBtn.clipsToBounds = true
        retrieveBtn.layer.cornerRadius = 18
        retrieveBtn.layer.borderWidth = 1
        retrieveBtn.layer.borderColor = lightGreen.cgColor
        retrieveBtn.addTarget(self, action: .headerBtnAction, for: .touchUpInside)
        retrieveBtn.tag = BTN_TAG_RETRIEVE
        contentView.addSubview(retrieveBtn)
        retrieveBtn.snp.makeConstraints { (make) in
            make.width.equalTo(100)
            make.height.equalTo(36)
            make.leftMargin.equalTo(20)
            make.topMargin.equalTo(56)
        }
        return headerView
    }
}
