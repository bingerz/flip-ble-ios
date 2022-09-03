//
//  BZOperationViewController.swift
//  Flip-BLE_Example
//
//  Created by Hanson on 2022/9/3.
//  Copyright © 2022 hanbing0604@aliyun.com. All rights reserved.
//

import Foundation
import UIKit

class BZServiceCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        initView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {
        btService = nil
    }
    
    var btService: CBService? {
        didSet {
            updateCellViewState()
        }
    }
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .black
        label.minimumScaleFactor = 0.8
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let subTitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .gray
        label.minimumScaleFactor = 0.8
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let descLabel: UILabel = {
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
        button.setTitle("View", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.setTitleColor(UIUtils.color(red: 48, green: 206, blue: 170, alpha: 1.0), for: .normal)
        button.setTitleColor(UIUtils.color(red: 43, green: 186, blue: 152, alpha: 1.0), for: .highlighted)
        button.titleLabel?.minimumScaleFactor = 0.5
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.setBackgroundImage(UIUtils.createImageWithColor(UIUtils.color(red: 255, green: 255, blue: 255, alpha: 1.0)), for: .normal)
        button.setBackgroundImage(UIUtils.createImageWithColor(UIUtils.color(red: 242, green: 255, blue: 252, alpha: 1.0)), for: .highlighted)
        button.clipsToBounds = true
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 1
        button.layer.borderColor = UIUtils.color(red: 48, green: 206, blue: 170, alpha: 1.0).cgColor
        button.isUserInteractionEnabled = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    fileprivate func initView() {
        self.containerView.addSubview(titleLabel)
        self.containerView.addSubview(subTitleLabel)
        self.containerView.addSubview(descLabel)
        self.contentView.addSubview(containerView)
        self.contentView.addSubview(funcButton)
        
        containerView.snp.makeConstraints { make in
            make.height.equalTo(80)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
        }
        
        subTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
        }
        
        descLabel.snp.makeConstraints { make in
            make.top.equalTo(subTitleLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
        }
        
        funcButton.snp.makeConstraints { make in
            make.width.equalTo(72)
            make.height.equalTo(32)
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview().offset(20)
        }
    }
    
    fileprivate func updateCellViewState() {
        if let service = btService {
            var characteristicCount = 0
            if let count = service.characteristics?.count {
                characteristicCount = count
            }
            titleLabel.text = "Service<\(String(describing: characteristicCount))>"
            subTitleLabel.text = service.uuid.uuidString
            descLabel.text = "Service Type: \(service.isPrimary ? "Primary" : "Secondary")"
        }
    }
}

class BZOperationViewController : UITableViewController {
    
    private let cellId = "CellId"
    
    @objc var peripheral: BZPeripheral?
    
    deinit {
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Service List"
        setupTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadTableView()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    func setupTableView() {
        tableView.register(BZServiceCell.self, forCellReuseIdentifier: cellId)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        tableView.separatorStyle = .none
    }
    
    func reloadTableView() {
        tableView.reloadData()
    }
    
    @objc func viewButtonClicked(sender: UIButton) {
        if let services = peripheral?.blePeripheral().services {
            showCharactList(services[sender.tag])
        }
    }
    
    func showCharactList(_ service: CBService?) {
        if let service = service {
            let vc = BZCharacteristicViewController()
            vc.peripheral = peripheral
            vc.service = service
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let count = peripheral?.blePeripheral().services?.count {
            return count
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId) as! BZServiceCell
        if let services = peripheral?.blePeripheral().services {
            cell.btService = services[indexPath.row]
            cell.funcButton.tag = indexPath.row;
            cell.funcButton.addTarget(self, action: #selector(viewButtonClicked(sender:)), for: .touchUpInside)
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if self.tableView == tableView {
            
        }
    }
}
