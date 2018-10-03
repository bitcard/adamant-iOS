//
//  WalletViewControllerBase.swift
//  Adamant
//
//  Created by Anokhov Pavel on 12.08.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import UIKit
import Eureka

class WalletViewControllerBase: FormViewController, WalletViewController {
	// MARK: - Rows
	enum BaseRows {
		case address, balance, send
		
		var tag: String {
			switch self {
			case .address: return "a"
			case .balance: return "b"
			case .send: return "s"
			}
		}
		
		var localized: String {
			switch self {
			case .address: return "Адрес"
			case . balance: return "Баланс"
			case .send: return "Отправить"
			}
		}
	}
	
	private let cellIdentifier = "cell"
	
	
	// MARK: - Dependencies
	
	var dialogService: DialogService!
	
	
	// MARK: - Properties, WalletViewController
	
	var viewController: UIViewController { return self }
	var height: CGFloat { return tableView.frame.origin.y + tableView.contentSize.height }
	
	var service: WalletService?
	
	// MARK: - IBOutlets
	
	@IBOutlet weak var walletTitleLabel: UILabel!
	
	
	// MARK: - Lifecycle
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		let section = Section()
		
		// MARK: Address
		let addressRow = LabelRow() {
			$0.tag = BaseRows.address.tag
			$0.title = BaseRows.address.localized
			$0.cell.selectionStyle = .gray
			
			if let wallet = service?.wallet {
				$0.value = wallet.address
			}
		}.cellUpdate { (cell, _) in
			cell.accessoryType = .disclosureIndicator
		}.onCellSelection { [weak self] (_, _) in
			let completion = { [weak self] in
				guard let tableView = self?.tableView, let indexPath = tableView.indexPathForSelectedRow else {
					return
				}
				
				tableView.deselectRow(at: indexPath, animated: true)
			}
			
			if let address = self?.service?.wallet?.address {
				
				let contentType = ShareContentType.address
				self?.dialogService.presentShareAlertFor(string: address,
														 types: contentType.shareTypes(sharingTip: address),
														 excludedActivityTypes: contentType.excludedActivityTypes,
														 animated: true,
														 completion: completion)
			}
		}
		
		section.append(addressRow)
		
		// MARK: Balance
		let balanceRow = AlertLabelRow() { [weak self] in
			$0.tag = BaseRows.balance.tag
			$0.title = BaseRows.balance.localized
			
			if let alertLabel = $0.cell.alertLabel {
				alertLabel.backgroundColor = UIColor.adamant.primary
				alertLabel.textColor = UIColor.white
				alertLabel.clipsToBounds = true
				alertLabel.textInsets = UIEdgeInsets(top: 1, left: 5, bottom: 1, right: 5)
				
				if let count = self?.service?.wallet?.notifications, count > 0 {
					alertLabel.text = String(count)
				} else {
					alertLabel.isHidden = true
				}
			}
			
			if let service = self?.service, let wallet = service.wallet {
				let symbol = type(of: service).currencySymbol
				$0.value = AdamantBalanceFormat.full.format(balance: wallet.balance, withCurrencySymbol: symbol)
			} else {
				$0.value = "0"
			}
		}
		
		if service is WalletServiceWithTransfers {
			balanceRow.cell.selectionStyle = .gray
			balanceRow.cellUpdate { (cell, _) in
				cell.accessoryType = .disclosureIndicator
			}.onCellSelection { [weak self] (_, _) in
				guard let service = self?.service as? WalletServiceWithTransfers else {
					return
				}
				
				self?.navigationController?.pushViewController(service.transferListViewController(), animated: true )
			}
		}
		
		section.append(balanceRow)
		
		// MARK: Send
		if service is WalletServiceWithSend {
			let sendRow = LabelRow() {
				$0.tag = BaseRows.send.tag
				$0.title = BaseRows.send.localized
				$0.cell.selectionStyle = .gray
			}.cellUpdate { (cell, _) in
				cell.accessoryType = .disclosureIndicator
			}.onCellSelection { [weak self] (_, _) in
				guard let service = self?.service as? WalletServiceWithSend else {
					return
				}
				
				let vc = service.transferViewController()
				if let v = vc as? TransferViewControllerBase {
					v.delegate = self
				}
				
				if let nav = self?.navigationController {
					nav.pushViewController(vc, animated: true)
				} else {
					self?.present(vc, animated: true)
				}
			}
			
			section.append(sendRow)
		}
		
		form.append(section)
		
		// MARK: Notification
		if let service = service {
			let callback = { [weak self] (notification: Notification) in
				guard let wallet = notification.userInfo?[AdamantUserInfoKey.WalletService.wallet] as? WalletAccount else {
					return
				}
				
				if let row: AlertLabelRow = self?.form.rowBy(tag: BaseRows.balance.tag) {
					let symbol = type(of: service).currencySymbol
					row.value = AdamantBalanceFormat.full.format(balance: wallet.balance, withCurrencySymbol: symbol)
					
					if wallet.notifications > 0 {
						row.cell.alertLabel.text = String(wallet.notifications)
						
						if row.cell.alertLabel.isHidden {
							row.cell.alertLabel.isHidden = false
						}
					} else {
						row.cell.alertLabel.isHidden = true
					}
					
					row.updateCell()
				}
			}
			
			NotificationCenter.default.addObserver(forName: service.walletUpdatedNotification,
												   object: service,
												   queue: OperationQueue.main,
												   using: callback)
		}
    }
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		if let indexPath = tableView.indexPathForSelectedRow {
			tableView.deselectRow(at: indexPath, animated: animated)
		}
	}
	
	override func viewDidLayoutSubviews() {
		NotificationCenter.default.post(name: Notification.Name.WalletViewController.heightUpdated, object: self)
	}
	
	override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
		return UIView()
	}
}


extension WalletViewControllerBase: TransferViewControllerDelegate {
	func transferViewControllerDidFinishTransfer(_ viewController: TransferViewControllerBase) {
		if let nav = navigationController, nav.topViewController == viewController {
			DispatchQueue.main.async {
				nav.popViewController(animated: true)
			}
		} else if presentedViewController == viewController {
			DispatchQueue.main.async { [weak self] in
				self?.dismiss(animated: true, completion: nil)
			}
		}
	}
}
