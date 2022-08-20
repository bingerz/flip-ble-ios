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

class BZDeviceCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        initView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {
        device = nil
    }
    
    var device: BZPeripheral? {
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
        button.setTitle("Disconnect", for: .normal)
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
    
    fileprivate func initView() {
        self.containerView.addSubview(nameLabel)
        self.containerView.addSubview(statusLabel)
        self.contentView.addSubview(containerView)
        self.contentView.addSubview(funcButton)
        
        containerView.snp.makeConstraints { make in
            make.height.equalTo(60)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
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
        
        funcButton.snp.makeConstraints { make in
            make.width.equalTo(100)
            make.height.equalTo(36)
//            make.leading.equalTo(containerView.snp.trailing).offset(6)
            make.trailing.equalToSuperview().offset(-40)
            make.centerY.equalToSuperview()
        }
    }
    
    fileprivate func updateDeviceViewState() {
        if let device = device {
            nameLabel.text = device.name()
            statusLabel.text = "RSSI: \(device.scannedRSSINumber.intValue)"
            funcButton.setTitle(device.isConnected() ? "Disconnect" : "Connect", for: .normal)
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
    
    fileprivate var scannedDeviceArray = [BZPeripheral]()
    fileprivate var connectedDeviceArray = [BZPeripheral]()
    
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
    
    func setupTableView() {
        tableView.register(BZDeviceCell.self, forCellReuseIdentifier: cellId)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        tableView.separatorStyle = .none
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
            scannedDeviceArray.removeAll()
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
    
    func insertScannedDevice(_ perpheral: BZPeripheral) {
        scannedDeviceArray.append(perpheral)
    }
    
    func removeScannedDevice(_ perpheral: BZPeripheral) {
        scannedDeviceArray.removeAll { $0.uuidString() == perpheral.uuidString() }
    }
    
    func insertConnectedDevice(_ perpheral: BZPeripheral) {
        connectedDeviceArray.append(perpheral)
    }
    
    func removeConnectedDevice(_ perpheral: BZPeripheral) {
        connectedDeviceArray.removeAll { $0.uuidString() == perpheral.uuidString() }
    }
    
    func startScanDevice() {
        let LLServiceUUID = "1803"
        let scanServices = [CBUUID(string: LLServiceUUID)]
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
        let deviceName: NSString = NSString(string: advDataDic[CBAdvertisementDataLocalNameKey] as! String)
        NSLog("Scan peripheral %@ name %@", peripheral.uuidString(), deviceName);
        insertScannedDevice(peripheral)
        reloadTableView()
    }
    
    func didScanFailed(_ error: Error!) {
        
    }
    
    func didConnecting() {
        
    }
    
    func didRetrieve(_ peripheral: BZPeripheral!) {
        
    }
    
    func didRestored(_ peripheral: BZPeripheral!) {
        
    }
    
    func didRetrieveConnected(_ peripheral: BZPeripheral!) {
        
    }
    
    func didConnected(_ peripheral: BZPeripheral!) {
        removeScannedDevice(peripheral)
        insertConnectedDevice(peripheral)
        reloadTableView()
    }
    
    func didConnectError(_ peripheral: BZPeripheral!, error: Error!) {
        
    }
    
    func didDisconnected(_ peripheral: BZPeripheral!, error: Error!) {
        removeConnectedDevice(peripheral)
        reloadTableView()
    }
    
    @objc func connectButtonClicked(sender: UIButton) {
        let device = scannedDeviceArray[sender.tag]
        device.connectStateDelegate = self
        centralManager.add(device)
        centralManager.connect(device)
    }
    
    @objc func disconnectButtonClicked(sender: UIButton) {
        let device = connectedDeviceArray[sender.tag]
        centralManager.cancel(device)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? connectedDeviceArray.count : scannedDeviceArray.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Connected Device" : "Scanned Device"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId) as! BZDeviceCell
        if indexPath.section == 0 {
            cell.device = connectedDeviceArray[indexPath.row]
            cell.funcButton.tag = indexPath.row;
            cell.funcButton.addTarget(self, action: #selector(disconnectButtonClicked(sender:)), for: .touchUpInside)
        } else if indexPath.section == 1 {
            cell.device = scannedDeviceArray[indexPath.row]
            cell.funcButton.tag = indexPath.row;
            cell.funcButton.addTarget(self, action: #selector(connectButtonClicked(sender:)), for: .touchUpInside)
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if self.tableView == tableView {
            if indexPath.section == 0 {
                let device = connectedDeviceArray[indexPath.row]
            } else if indexPath.section == 1 {
                let device = scannedDeviceArray[indexPath.row]
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
