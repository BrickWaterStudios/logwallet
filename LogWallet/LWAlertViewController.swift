//
//  LWAlertViewController.swift
//  LogWallet
//
//  Created by Erik Bean on 11/10/21.
//  Copyright © 2021 Aaron Voisine. All rights reserved.
//

import UIKit

@objc class LWAlertViewController: UIViewController {
    
    enum AlertAdditionType {
        case okButton, cancelButton, customPrimaryButton, customSecondaryButton
        case image
    }
    
    @IBOutlet private weak var titleLabel: UILabel? {
        didSet {
            self.titleLabel?.text = title
        }
    }
    @IBOutlet private weak var messageLabel: UILabel? {
        didSet {
            self.messageLabel?.text = message
        }
    }
    
    @IBOutlet private weak var secondaryButton: UIButton? {
        didSet {
            if let action = secondaryButtonAction {
                secondaryButton?.setTitle(secondaryButtonText, for: .normal)
                secondaryButton?.addAction(action, for: .touchUpInside)
                secondaryButton?.isHidden = true
            }
        }
    }
    @IBOutlet private weak var primaryButton: UIButton? {
        didSet {
            if let action = primaryButtonAction {
                primaryButton?.setTitle(primaryButtonText, for: .normal)
                primaryButton?.addAction(action, for: .touchUpInside)
                primaryButton?.isHidden = true
            }
        }
    }
    @IBOutlet private weak var stack: UIStackView? {
        didSet {
            for i in arrangedViews {
                stack?.addArrangedSubview(i)
            }
        }
    }
    
    override var title: String? {
        didSet {
            if title == nil || title == "" {
                titleLabel?.isHidden = true
            } else {
                titleLabel?.text = title
                titleLabel?.isHidden = false
            }
        }
    }
    
    fileprivate var rowTitles: [String]?
    fileprivate var transactions: NSArray?
    fileprivate var moreTx: Bool = false
    
    var message: String? {
        didSet {
            if message == nil || message == "" {
                messageLabel?.isHidden = true
            } else {
                messageLabel?.text = message
                messageLabel?.isHidden = false
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        primaryButton?.isHidden = true
        secondaryButton?.isHidden = true
    }
    
    var arrangedViews: [UIView] = []
    
    func addTableView(_ delegate: UITableViewDelegate, titles: [String]?, transactions: NSArray?, moreTx: Bool = false) {
        self.rowTitles = titles
        self.transactions = transactions
        self.moreTx = moreTx
        let tableView = UITableView()
        tableView.dataSource = self
        tableView.accessibilityIdentifier = "LWAlertViewController.TableView"
        tableView.heightAnchor.constraint(equalToConstant: 150).isActive = true
        tableView.alert = self
        tableView.backgroundColor = .clear
        arrangedViews.append(tableView)
        stack?.addArrangedSubview(tableView)
    }
    
    func addObject(_ type: AlertAdditionType, text: String? = nil, action: UIAction? = nil, image: UIImage? = nil) {
        switch type {
        case .okButton, .customPrimaryButton:
            let okAction = UIAction { _ in self.dismiss(animated: true, completion: nil) }
            let button = UIButton(type: .system, primaryAction: (type == .okButton) ? okAction : action)
            button.setTitle(type == .okButton ? "ok" : text, for: .normal)
            button.setTitleColor(.darkGray, for: .normal)
            button.titleLabel?.font = UIFont(name: "HelveticaNeue-Medium", size: 12)
            button.setBackgroundImage(UIImage(named: "button-bg-blue"), for: .normal)
            button.heightAnchor.constraint(equalToConstant: 44.0).isActive = true
            button.layoutIfNeeded()
            arrangedViews.append(button)
            stack?.addArrangedSubview(button)
        case .cancelButton, .customSecondaryButton:
            var action = action
            if type == .cancelButton {
                action = UIAction { _ in
                    self.dismiss(animated: true, completion: nil)
                    return
                }
            }
            let button = UIButton(type: .system, primaryAction: action)
            button.setTitle(type == .cancelButton ? "cancel" : text, for: .normal)
            button.setTitleColor(.darkGray, for: .normal)
            button.titleLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 12)
            button.setBackgroundImage(UIImage(named: "button-bg-blue"), for: .normal)
            button.heightAnchor.constraint(equalToConstant: 44.0).isActive = true
            arrangedViews.append(button)
            stack?.addArrangedSubview(button)
        case .image:
            let imageView = UIImageView(image: image)
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 1).isActive = true
            imageView.layer.cornerRadius = 5
            imageView.clipsToBounds = true
            arrangedViews.append(imageView)
            stack?.addArrangedSubview(imageView)
        }
    }
    
    private var primaryButtonText: String?
    private var primaryButtonAction: UIAction?
    private var secondaryButtonText: String?
    private var secondaryButtonAction: UIAction?
    
    func presentWithOkOnly(on presenter: UIViewController) {
        addObject(.okButton)
        willMove(toParent: presenter)
        modalPresentationStyle = .overFullScreen
        presenter.present(self, animated: true, completion: nil)
    }
    
    func present(on presenter: UIViewController, animated: Bool = true) {
        willMove(toParent: presenter)
        modalPresentationStyle = .overFullScreen
        presenter.present(self, animated: animated, completion: nil)
    }
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)?) {
        willMove(toParent: nil)
        super.dismiss(animated: flag, completion: completion)
    }
    
    init() {
        super.init(nibName: "LWAlertViewController", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {
        sharedAlert = nil
    }
}

extension LWAlertViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let transactions = transactions {
            if moreTx {
                return transactions.count + 1
            } else {
                return transactions.count
            }
        } else if let rowTitles = rowTitles {
            return rowTitles.count
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let rowTitles = rowTitles {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            var content = cell.defaultContentConfiguration()
            content.text = rowTitles[indexPath.row]
            cell.contentConfiguration = content
            cell.backgroundColor = .clear
            return cell
        } else if let transactions = transactions {
            if indexPath.row > 0 && indexPath.row >= self.transactions?.count ?? 0 {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                var content = cell.defaultContentConfiguration()
                content.text = NSLocalizedString("more...", comment: "");
                cell.contentConfiguration = content
                cell.backgroundColor = .clear
                return cell
            } else if transactions.count > 0 {
                guard let manager = BRWalletManager.sharedInstance() else {
                    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                    var content = cell.defaultContentConfiguration()
                    content.text = "error"
                    cell.contentConfiguration = content
                    cell.backgroundColor = .clear
                    return cell
                }
                var textLabel, unconfirmedLabel, sentLabel, localCurrencyLabel, balanceLabel, localBalanceLabel: UILabel?
                var detailTextLabel: BRCopyLabel?
                let cell = tableView.dequeueReusableCell(withIdentifier: "TransactionCell")
                textLabel = cell?.viewWithTag(1) as? UILabel
                detailTextLabel = cell?.viewWithTag(2) as? BRCopyLabel
                unconfirmedLabel = cell?.viewWithTag(3) as? UILabel
                localCurrencyLabel = cell?.viewWithTag(5) as? UILabel
                sentLabel = cell?.viewWithTag(6) as? UILabel
                balanceLabel = cell?.viewWithTag(7) as? UILabel
                localBalanceLabel = cell?.viewWithTag(8) as? UILabel
                
                guard let transaction = transactions[indexPath.row] as? BRTransaction else {
                    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                    var content = cell.defaultContentConfiguration()
                    content.text = "error"
                    cell.contentConfiguration = content
                    cell.backgroundColor = .clear
                    return cell
                }
                let received = manager.wallet.amountReceived(from: transaction)
                let sent = manager.wallet.amountSent(by: transaction)
                let balanace = manager.wallet.balance(after: transaction)
                let height = BRPeerManager.sharedInstance().lastBlockHeight
                let confirms = (transaction.blockHeight == INT32_MAX) ? 0 : (height - transaction.blockHeight) + 1
                let peerManager = BRPeerManager.sharedInstance()
                let peerCount = peerManager?.peerCount ?? 0
                let relayCount = peerManager?.relayCount(forTransaction: transaction.txHash) ?? 0
                sentLabel?.isHidden = true
                unconfirmedLabel?.isHidden = false
                detailTextLabel?.text = BRSettingsViewController().date(forTx: transaction)
                balanceLabel?.text = manager.string(forAmount: Int64(balanace))
                localBalanceLabel?.text = "\(manager.localCurrencyString(forAmount: Int64(balanace)) ?? "0")"
                
                if confirms == 0, !manager.wallet.transactionIsValid(transaction) {
                    unconfirmedLabel?.text = "INVALID"
                    unconfirmedLabel?.backgroundColor = .red
                } else if confirms == 0, manager.wallet.transactionIsPostdated(transaction, atBlockHeight: height) {
                    unconfirmedLabel?.text = "post-dated"
                    unconfirmedLabel?.backgroundColor = .red
                } else if confirms == 0, (peerCount == 0 || relayCount < peerCount) {
                    unconfirmedLabel?.text = "unverified"
                } else if confirms < 6 {
                    unconfirmedLabel?.text = "\(confirms) confirmation\(confirms > 0 ? "s" : "")"
                } else {
                    unconfirmedLabel?.text = nil
                    unconfirmedLabel?.isHidden = true
                    sentLabel?.isHidden = false
                }
                
                if manager.wallet.address(for: transaction) != nil, sent > 0 {
                    textLabel?.text = manager.string(forAmount: Int64(sent))
                    localCurrencyLabel?.text = "\(manager.localCurrencyString(forAmount: Int64(sent)) ?? "0")"
                    sentLabel?.text = "moved"
                    sentLabel?.textColor = .black
                } else if sent > 0 {
                    textLabel?.text = manager.string(forAmount: Int64(received))
                    localCurrencyLabel?.text = "\(manager.localCurrencyString(forAmount: Int64(received)) ?? "0")"
                    sentLabel?.text = "received"
                    sentLabel?.textColor  = UIColor(red: 0, green: 0.75, blue: 0, alpha: 1)
                }
                
                if (unconfirmedLabel?.isHidden ?? true) != true  {
                    unconfirmedLabel?.layer.cornerRadius = 3
                    unconfirmedLabel?.backgroundColor = .lightGray
                    unconfirmedLabel?.text = unconfirmedLabel?.text?.appending("  ")
                } else {
                    sentLabel?.layer.cornerRadius = 3
                    sentLabel?.layer.borderWidth = 0.5
                    sentLabel?.text = sentLabel?.text?.appending("  ")
                    sentLabel?.layer.borderColor = sentLabel?.textColor.cgColor
                    sentLabel?.highlightedTextColor = sentLabel?.textColor
                }
                guard let cell = cell else {
                    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                    var content = cell.defaultContentConfiguration()
                    content.text = "error"
                    cell.contentConfiguration = content
                    cell.backgroundColor = .clear
                    return cell
                }
                return cell
            } else {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                var content = cell.defaultContentConfiguration()
                content.text = "error"
                cell.contentConfiguration = content
                cell.backgroundColor = .clear
                return cell
            }
        }
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        content.text = "error"
        cell.contentConfiguration = content
        cell.backgroundColor = .clear
        return cell
    }
}
