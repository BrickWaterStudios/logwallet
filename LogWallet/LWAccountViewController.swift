//
//  LWAccountViewController.swift
//  LogWallet
//
//  Created by Erik Bean on 11/6/21.
//  Copyright © 2021 Aaron Voisine. All rights reserved.
//

import AVFoundation
import UIKit

private protocol LWButtonTitle {
    var title: String { get }
}

private protocol LWButtonInit {
    init?(row: Int)
}

class LWButtonCell: UITableViewCell, LWButtonTitle {
    @IBOutlet weak var label: UILabel?
    
    var title: String = "_unknown_button_" {
        didSet {
            self.label?.text = title
        }
    }
}

// MARK: - Account View Controller -
class LWAccountViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var walletSummary: UILabel?
    
    var okAddress: NSString?
    var request: BRPaymentRequest?
    var protocolRequest: BRPaymentProtocolRequest?
    var protoReqAmount: UInt64?
    var tx: BRTransaction?
    var didAskFee: Bool = false
    var removeFee: Bool = false
    var sweepTx: BRTransaction?
    var scanController: BRScanViewController?
    var transactions: NSArray?
    var moreTx: Bool = false
    var balanceObserver:Any?
    
    var titles: [[String]] = [["copy my Woodcoin Wallet addess", "show my qr code", "scan a qr code", "pay address in clipboard", "my transaction history"], ["backup phrase", "change pin", "set currency", "manage standard fees"], ["import private key", "rescan blockchain"], ["reset/start new wallet"], ["about"]]
    var wallet: BRWallet!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let manager = BRWalletManager.sharedInstance()
        let array = manager?.wallet.recentTransactions ?? []
        self.transactions = NSArray(array: array).subarray(with: NSMakeRange(0, (array.count > 5 && self.moreTx) ? 5 : array.count)) as NSArray
        
        if self.balanceObserver != nil {
            self.balanceObserver = NotificationCenter.default.addObserver(forName: .init(BRWalletBalanceChangedNotification), object: nil, queue: nil) { notification in
                guard let manager = manager else { return }
                let array = manager.wallet.recentTransactions ?? []
                if self.moreTx {
                    self.transactions = NSArray(array: array).subarray(with: NSMakeRange(0, array.count > 5 ? 5 : array.count)) as NSArray
                    self.moreTx = (array.count > 5) ? true : false
                } else {
                    self.transactions = NSArray(array: array)
                }
                
                self.walletSummary?.text = manager.string(forAmount: Int64(self.wallet.balance))
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView?.delegate = self
        tableView?.dataSource = self
        guard let wallet = BRWalletManager.sharedInstance()?.wallet else {
            // Present alert saying wallet is invalid
            navigationController?.popToRootViewController(animated: true)
            return
        }
        self.wallet = wallet
        let manager = BRWalletManager.sharedInstance()
        self.walletSummary?.text = manager?.string(forAmount: Int64(wallet.balance))
        self.moreTx = (BRWalletManager.sharedInstance().wallet.recentTransactions.count > 5) ? true : false
    }
}

extension LWAccountViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        titles.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        titles[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "LWButtonCell", for: indexPath) as? LWButtonCell else {
            fatalError("Could not create LWButtonCell")
        }
        cell.title = titles[indexPath.section][indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if tableView.accessibilityIdentifier == "LWAlertViewController.TableView", let manager = BRWalletManager.sharedInstance() {
            if indexPath.row > 0 && indexPath.row >= self.transactions?.count ?? 0 {
                tableView.beginUpdates()
                let transactions = NSArray(array: manager.wallet.recentTransactions)
                self.transactions = transactions
                self.moreTx = false
                tableView.deleteRows(at: [IndexPath(row: 5, section: 0)], with: .fade)
                let array = NSMutableArray(capacity: transactions.count - 5)
                
                for i in 5..<(transactions.count) {
                    array.add(IndexPath(row: i, section: 0))
                }
                
                tableView.insertRows(at: array as! [IndexPath], with: .top)
                tableView.endUpdates()
            } else if self.transactions?.count ?? 0 > 0 {
                guard let detailsController = UIStoryboard.inObjC.viewController(for: "TxDetailViewController") as? BRTxDetailViewController, let transaction = self.transactions?[indexPath.row] as? BRTransaction else { return }
                detailsController.transaction = transaction
                detailsController.txDateString = BRSettingsViewController().date(forTx: transaction)
                navigationController?.pushViewController(detailsController, animated: true)
            }
            return
        }
        
        let address = BRWalletManager.sharedInstance().wallet.receiveAddress
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                // MARK: Copy Wallet Address
                let alert = LWAlertViewController()
                alert.title = "copy my wallet address"
                alert.message = address
                alert.addObject(.cancelButton)
                alert.addObject(.customPrimaryButton, text: "copy address", action: UIAction { _ in
                    UIPasteboard.general.string = address
                    alert.dismiss(animated: true, completion: nil)
                })
                alert.present(on: self)
            case 1:
                // MARK: Show My QR Code
                guard let address = address, let request = BRPaymentRequest(string: address).data else { return }
                DispatchQueue.main.async {
                    if let filter = CIFilter(name: "CIQRCodeGenerator") {
                        filter.setValue(request, forKey: "inputMessage")
                        let transform = CGAffineTransform(scaleX: 3, y: 3)
                        if let output = filter.outputImage?.transformed(by: transform) {
                            let alert = LWAlertViewController()
                            alert.title = "my qr code"
                            alert.addObject(.image, image: UIImage(ciImage: output))
                            alert.addObject(.customPrimaryButton, text: "done", action: UIAction { _ in
                                alert.dismiss(animated: true, completion: nil)
                            })
                            alert.present(on: self)
                        }
                    }
                }
            case 2:
                // MARK: Scan QR Code
                presentScanner()
            case 3:
                // MARK: Pay Clipboard
                payToClipboard()
            case 4:
                // MARK: My Transaction History
                let alert = LWAlertViewController()
                alert.title = "transaction history"
                if self.transactions?.count ?? 0 == 0 {
                    alert.message = "no transaction history found"
                } else {
                    alert.addTableView(self, titles: nil, transactions: transactions, moreTx: moreTx)
                }
                alert.addObject(.okButton)
            default:
                outOfBounds()
            }
        case 1:
            switch indexPath.row {
            case 0:
                // MARK: Backup Phrase
                present(UIStoryboard.inSwift.viewController(for: "backup"), animated: true, completion: nil)
            case 1:
                // change pin
                guard let pinCon = UIStoryboard.inSwift.viewController(for: "pinNav") as? BRPINViewController else { return }
                pinCon.changePin = true
                pinCon.cancelable = true
                pinCon.appeared = true
                pinCon.title = NSLocalizedString("reset pin", comment: "")
                present(pinCon, animated: true, completion: nil)
            case 2:
                // MARK: Set Currancy
                guard let manager = BRWalletManager.sharedInstance(), let codes = manager.currencyCodes as? [String] else {
                    let alert = LWAlertViewController()
                    alert.title = "could not find currency list"
                    alert.presentWithOkOnly(on: self)
                    return
                }
                let alert = LWAlertViewController()
                alert.title = "local currency"
                alert.addTableView(self, titles: codes, transactions: nil, moreTx: moreTx)
                alert.addObject(.cancelButton)
                alert.presentWithOkOnly(on: self)
            case 3:
                // MARK: Standard Fees
                let alert = LWAlertViewController()
                alert.title = "manage standard fees"
                let key = "SETTINGS_SKIP_FEE"
                let useFees = UserDefaults.standard.bool(forKey: key)
                alert.message = "would you like to \(useFees ? "disable" : "enable") standard fees?"
                alert.addObject(.customSecondaryButton, text: "disable", action: UIAction { _ in
                    UserDefaults.standard.set(false, forKey: key)
                    alert.dismiss(animated: true, completion: nil)
                })
                alert.addObject(.customPrimaryButton, text: "enable", action: UIAction { _ in
                    UserDefaults.standard.set(true, forKey: key)
                    alert.dismiss(animated: true, completion: nil)
                })
                alert.present(on: self)
            default:
                outOfBounds()
            }
        case 2:
            switch indexPath.row {
            case 0:
                // MARK: Import Private Key
                presentScanner()
            case 1:
                // MARK: Rescan Blockchain
                BRPeerManager.sharedInstance().rescan()
                let alert = LWAlertViewController()
                alert.title = "rescanning"
                alert.message = "please allow some time for the blockchain to be rescanned, thank you"
                alert.presentWithOkOnly(on: self)
                break
            default:
                outOfBounds()
            }
        case 3:
            switch indexPath.row {
            case 0:
                // MARK: Reset/Restore Another Wallet
                present(UIStoryboard.inObjC.viewController(for: "restore"), animated: true, completion: nil)
            default:
                outOfBounds()
            }
        case 4:
            switch indexPath.row {
            case 0:
                // MARK: More Information
                let alert = LWAlertViewController()
                alert.title = "Natural LogWallet"
                alert.message = "built by Brick Water Studios in association with woodcoin\n\ncopyright 2021\nBrick Water Studios - woodcoin"
                alert.addObject(.customSecondaryButton, text: "woodcoin.org", action: UIAction { _ in
                    alert.dismiss(animated: true, completion: nil)
                    guard let url = URL(string: "https://woodcoin.org") else { return }
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                })
                alert.addObject(.customSecondaryButton, text: "Brick Water Studios", action: UIAction { _ in
                    alert.dismiss(animated: true, completion: nil)
                    guard let url = URL(string: "https://www.brickwaterstudios.com") else { return }
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                })
                alert.addObject(.okButton)
                alert.present(on: self)
            default:
                outOfBounds()
            }
        default:
            outOfBounds()
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    private func outOfBounds() {
        fatalError("Selected Option is out of bounds")
    }
}

extension LWAccountViewController {
    
    func payToClipboard() {
        guard UIPasteboard.general.hasStrings, let string = UIPasteboard.general.string else {
            let alert = LWAlertViewController()
            alert.title = "No Address Found"
            alert.presentWithOkOnly(on: self)
            return
        }
        guard let manager = BRWalletManager.sharedInstance() else {
            let alert = LWAlertViewController()
            alert.title = "payment failed"
            alert.presentWithOkOnly(on: self)
            return
        }
        let charSet = NSCharacterSet.alphanumerics.inverted
        var i = [string]
        i.append(contentsOf: string.components(separatedBy: charSet))
        for string in i {
            let request = BRPaymentRequest(string: string)
            let nsstring = NSString(string: string)
            guard let hexToData = nsstring.hexToData() else { continue }
            let reversedData = NSData(data: NSData(data: hexToData).reverse())
            let recentTransactions: NSArray? = manager.wallet.recentTransactions as NSArray?
            let recentTransaction = recentTransactions?.value(forKey: "txHash") as? NSOrderedSet
            
            if reversedData.length == 32, recentTransaction?.contains(reversedData) ?? false {
                continue
            }
            
            if request?.isValid ?? false || nsstring.isValidBitcoinPrivateKey() || nsstring.isValidBitcoinBIP38Key() {
                self.complete(request)
                return
            }
        }
        
        let alert = LWAlertViewController()
        alert.title = "clipboard doesn't contain a valid woodcoin address"
        alert.presentWithOkOnly(on: self)
    }
    
    func complete(_ request: BRPaymentRequest!) {
        // 1
        if !request.isValid {
            let string = NSString(string: request.paymentAddress)
            if string.isValidBitcoinPrivateKey(), string.isValidBitcoinBIP38Key() {
                confirmSweep(request.paymentAddress)
            } else {
                let alert = LWAlertViewController()
                alert.title = "not a valid woodcoin address"
                alert.presentWithOkOnly(on: self)
            }
        }
        
        // 2
        guard request.r != nil else {
            let alert = LWAlertViewController()
            alert.title = "No Address Found"
            alert.presentWithOkOnly(on: self)
            return
        }
        if NSString(string: request.r).length > 0 {
            BRPaymentRequest.fetch(request.r, timeout: 20.0) { request, error in
                if let error = error {
                    let alert = LWAlertViewController()
                    alert.title = "couldn't make payment"
                    alert.message = error.localizedDescription.lowercased()
                    alert.presentWithOkOnly(on: self)
                } else {
                    self.confirmProtocolRequest(request)
                }
            }
        }
        
        // 3
        guard let manager = BRWalletManager.sharedInstance() else { return }
        
        // 4
        if manager.wallet.containsAddress(request.paymentAddress) {
            let alert = LWAlertViewController()
            alert.title = "this payment address is already in your wallet"
            alert.presentWithOkOnly(on: self)
        // 5
        } else if let address = okAddress {
            if String(address) != request.paymentAddress, manager.wallet.addressIsUsed(request.paymentAddress), UIPasteboard.general.string == request.paymentAddress {
                self.request = request
                self.okAddress = NSString(string: request.paymentAddress)
                // 6
                let alert = LWAlertViewController()
                alert.title = "WARNING"
                alert.message = "\nADDRESS ALREADY USED\n\nwoodcoin addresses are intented for single use only\n\n re-use reduces privacy for both you and the recipient and can result in loss if the recipient doesn't directly control the address"
                // 8
                alert.addObject(.customSecondaryButton, text: "cancel", action: UIAction { _ in
                    alert.dismiss(animated: true, completion: nil)
                    self.dismiss(animated: true, completion: nil)
                })
                // 7
                alert.addObject(.customPrimaryButton, text: "ignore", action: UIAction { _ in
                    if let protocolRequest = self.protocolRequest {
                        self.confirmProtocolRequest(protocolRequest)
                    } else if let request = self.request {
                        self.complete(request)
                    }
                })
                alert.present(on: self)
            // 9
            } else if request.amount == 0 {
                guard let amountVC = UIStoryboard.inObjC.viewController(for: "AmountViewController") as? BRAmountViewController else {
                    self.dismiss(animated: true, completion: nil)
                    return
                }
                amountVC.info = request
                amountVC.delegate = self
                let cfstring: CFMutableString = NSMutableString(string: request.label)
                CFStringTransform(cfstring, nil, kCFStringTransformToUnicodeName, false)
                amountVC.to = (NSString(string: request.label).length > 0) ? cfstring as String : NSString.base58(with: NSString(string: request.paymentAddress).base58ToData())
                amountVC.navigationItem.title = "\(manager.string(forAmount: Int64(manager.wallet.balance)) ?? "") \(manager.localCurrencyString(forAmount: Int64(manager.wallet.balance)) ?? "")"
                self.navigationController?.pushViewController(amountVC, animated: true)
            // 10
            } else if request.amount < tx_min_output_amount {
                let i = "woodcoin payments can't be less than"
                let j = manager.string(forAmount: tx_min_output_amount) ?? ""
                let k = i.appending(j)
                // 11
                let alert = LWAlertViewController()
                alert.title = "couldn't make payment"
                alert.message = k
                alert.addObject(.cancelButton)
                alert.present(on: self)
            // 12
            } else {
                self.request = request
                // 13
                self.tx = manager.wallet.transaction(for: request.amount, to: request.paymentAddress, withFee: false)
                // 14
                var amount = (tx != nil) ? request.amount : manager.wallet.amountSent(by: tx) - manager.wallet.amountReceived(from: tx)
                var fee: UInt64 = 0
                // 15
                if tx != nil, manager.wallet.blockHeight(untilFree: tx) <= BRPeerManager.sharedInstance().lastBlockHeight + 1 && !didAskFee && UserDefaults.standard.bool(forKey: "SETTINGS_SKIP_FEE") {
                    // 16
                    let alert = LWAlertViewController()
                    let standardFee: Int64 = Int64(tx!.standardFee)
                    let s1: String = manager.string(forAmount: standardFee)
                    let s2: String = manager.localCurrencyString(forAmount: standardFee)
                    alert.title = "woodcoin network fee"
                    alert.message = "the standard woodcoin network fee for this transaction is \(s1) (\(s2)\n\nremoving this fee may delay confirmation"
                    // 27
                    alert.addObject(.customSecondaryButton, text: "remove fee", action: UIAction { _ in
                        alert.dismiss(animated: true, completion: nil)
                        self.didAskFee = true
                        if let request = self.protocolRequest {
                            self.confirmProtocolRequest(request)
                        } else if let request = self.request {
                            self.complete(request)
                        }
                    })
                    // 17
                    alert.addObject(.customPrimaryButton, text: "ok", action: UIAction { [weak self] _ in
                        // 18
                        guard let self = self, let request = self.protocolRequest else {
                            alert.dismiss(animated: true, completion: nil)
                            return
                        }
                        // 19
                        guard let tx = self.tx else {
                            let alert = LWAlertViewController()
                            alert.title = "insufficient funds"
                            alert.presentWithOkOnly(on: self)
                            return
                        }
                        // 20
                        NSLog("signing transaction")
                        // 21
                        if !manager.wallet.sign(tx) {
                            let alert = LWAlertViewController()
                            alert.title = "couldn't make payment"
                            alert.message = "error signing woodcoin transaction"
                            alert.presentWithOkOnly(on: self)
                        }
                        // 22
                        NSLog("signed transaction: \(NSString.hex(with: tx.data) ?? "invalid")")
                        // 23
                        BRPeerManager.sharedInstance().publishTransaction(tx) { error in
                            // 24
                            if NSString(string: request.details.paymentURL).length > 0 {
                                return
                            }
                            // 25
                            if error != nil {
                                let alert = LWAlertViewController()
                                alert.title = "couldn't make payment"
                                alert.message = "error signing woodcoin transaction"
                                alert.presentWithOkOnly(on: self)
                            // 26
                            } else {
                                let alert = LWAlertViewController()
                                alert.title = "sent!"
                                alert.presentWithOkOnly(on: self)
                                
                                self.reset()
                                
                                if let error = error {
                                    NSLog(error.localizedDescription)
                                }
                            }
                        }
                    })
                    // 28
                    alert.present(on: self)
                    // 29
                    if !self.removeFee {
                        fee = self.tx?.standardFee ?? 0
                        amount += fee
                        self.tx = manager.wallet.transaction(for: request.amount, to: request.paymentAddress, withFee: true)
                        if self.tx != nil {
                            amount = manager.wallet.amountSent(by: self.tx) - manager.wallet.amountReceived(from: self.tx)
                            fee = manager.wallet.fee(for: self.tx)
                        }
                    }
                    // 30
                    self.confirmAmount(amount: Int64(amount), fee: Int64(fee), address: request.paymentAddress, name: request.label, memo: request.message, isSecure: false)
                }
            }
        }
    }
    
    func reset() {
        self.tx = nil
        self.sweepTx = nil
        self.request = nil
        self.protocolRequest = nil
        self.protoReqAmount = 0
        self.okAddress = nil
        self.didAskFee = false
        self.removeFee = false
    }
    
    var tx_min_output_amount: Int64 {
        Int64(100000)*3*(34+148)/1000
    }
    
    func confirmProtocolRequest(_ request: BRPaymentProtocolRequest!) {
        let valid = request.isValid
        
        if !valid && request.errorMessage == NSLocalizedString("request expired", comment: "") {
            let alert = LWAlertViewController()
            alert.title = "bad payment request"
            alert.message = request.errorMessage
            alert.presentWithOkOnly(on: self)
        }
        
        guard let data = request.details.outputScripts.first as? Data else { return }
        var address = NSString.address(withScriptPubKey: data)
        let manager = BRWalletManager.sharedInstance()
        var amount: UInt64 = 0
        var fee: UInt64 = 0
        var outputTooSmall = false
        
        for number in request.details.outputAmounts {
            guard let number = number as? NSNumber else { continue }
            if let i = UInt64(exactly: number), i < tx_min_output_amount {
                outputTooSmall = true
                amount += i
            }
        }
        
        if manager?.wallet.containsAddress(address) ?? false {
            let alert = LWAlertViewController ()
            alert.message = "this payment address is already in your wallet"
            alert.presentWithOkOnly(on: self)
        } else if self.okAddress != address as NSString? && manager?.wallet.addressIsUsed(address) ?? false && UIPasteboard.general.string == address {
            self.protocolRequest = request
            self.okAddress = address as NSString? as NSString?
            let alert = LWAlertViewController()
            alert.title = "WARNING"
            alert.message = "\nADDRESS ALREADY USED\n\nwoodcoin addresses are intented for single use only\n\nre-use reduces privacy for both you and the recipient and can result in loss if the recipient doesn't directly control the address"
            alert.addObject(.customSecondaryButton, text: "ignore", action: UIAction { _ in
                alert.dismiss(animated: true, completion: nil)
                self.didAskFee = true
                if let request = self.protocolRequest {
                    self.confirmProtocolRequest(request)
                } else if let request = self.request {
                    self.complete(request)
                }
            })
            alert.addObject(.okButton)
            alert.present(on: self)
        } else if amount == 0 && self.protoReqAmount == 0 {
            guard let amountController = UIStoryboard.inObjC.viewController(for: "AmountViewController") as? BRAmountViewController else { return }
            amountController.info = request
            amountController.delegate = self
            
            if NSString(string: request.commonName).length > 0 {
                if valid && request.pkiType != .none {
                    amountController.to = "\\xF0\\x9F\\x94\\x92 \(request.commonName.sanitized())"
                } else if request.errorMessage.count > 0 {
                    amountController.to = "\\xE2\\x9D\\x8C \(request.commonName.sanitized())"
                } else {
                    amountController.to = request.commonName.sanitized()
                }
            } else {
                guard let data = request.details.outputScripts.first as? Data else { return }
                amountController.to = NSString.address(withScriptPubKey: data)
                amountController.navigationItem.title = "\(manager?.string(forAmount: Int64(manager?.wallet.balance ?? 0)) ?? "") \(manager?.localCurrencyString(forAmount: Int64(manager?.wallet.balance ?? 0)) ?? "")"
                self.navigationController?.pushViewController(amountController, animated: true)
            }
        } else if amount > 0 && amount < tx_min_output_amount {
            let alert = LWAlertViewController()
            alert.title = "couldn't make payment"
            alert.message = "woodcoin payments can't be less than \(manager?.string(forAmount: tx_min_output_amount) ?? "0")"
            alert.presentWithOkOnly(on: self)
        } else if amount > 0 && outputTooSmall {
            let alert = LWAlertViewController()
            alert.title = "couldn't make payment"
            alert.message = "woodcoin payments can't be less than \(manager?.string(forAmount: tx_min_output_amount) ?? "0")"
            alert.presentWithOkOnly(on: self)
        } else {
            self.protocolRequest = request
            
            if self.protoReqAmount ?? 0 > 0 {
                self.tx = manager?.wallet.transaction(forAmounts: [self.protoReqAmount ?? 0], toOutputScripts: [request.details.outputScripts.first as Any], withFee: false)
            } else {
                self.tx = manager?.wallet.transaction(forAmounts: request.details.outputAmounts, toOutputScripts: request.details.outputScripts, withFee: false)
            }
            
            if let transaction = self.tx, manager?.wallet.blockHeight(untilFree: transaction) ?? 0 <= BRPeerManager.sharedInstance().lastBlockHeight + 1, !self.didAskFee, UserDefaults.standard.bool(forKey: "SETTINGS_SKIP_FEE") {
                let alert = LWAlertViewController()
                alert.title = "woodcoin network fee"
                alert.message = "the standard woodcoin network fee for this transaction is \(manager?.string(forAmount: Int64(self.tx?.standardFee ?? 0)) ?? "0") (\(manager?.localCurrencyString(forAmount: Int64(self.tx?.standardFee ?? 0)) ?? "0")\n\nremoving this fee may delay confirmation"
                alert.addObject(.customSecondaryButton, text: "remove fee", action: UIAction { _ in
                    alert.dismiss(animated: true, completion: nil)
                    self.didAskFee = true
                    if let request = self.protocolRequest {
                        self.confirmProtocolRequest(request)
                    } else if let request = self.request {
                        self.complete(request)
                    }
                })
                alert.addObject(.okButton)
                alert.present(on: self)
            }
            
            if let transaction = self.tx {
                amount = (manager?.wallet.amountSent(by: transaction) ?? 0) - (manager?.wallet.amountReceived(from: transaction) ?? 0)
            }
            
            if !removeFee {
                fee = self.tx?.standardFee ?? 0
                amount += fee
                
                if self.protoReqAmount ?? 0 > 0 {
                    self.tx = manager?.wallet.transaction(forAmounts: [self.protoReqAmount ?? 0], toOutputScripts: [request.details.outputScripts.first as Any], withFee: true)
                } else {
                    self.tx = manager?.wallet.transaction(forAmounts: request.details.outputAmounts, toOutputScripts: request.details.outputScripts, withFee: true)
                }
                
                if let transaction = self.tx {
                    amount = (manager?.wallet.amountSent(by: transaction) ?? 0) - (manager?.wallet.amountReceived(from: transaction) ?? 0)
                    fee = manager?.wallet.fee(for: transaction) ?? 0
                }
            }
        }
        
        for script in request.details.outputScripts {
            guard let script = script as? Data else { return }
            let addr = NSString.address(withScriptPubKey: script)
            if addr == nil || addr?.isEmpty ?? true {
                if address?.contains(NSLocalizedString("unrecognized address", comment: "")) ?? false {
                    address = address?.appending("\((address?.isEmpty ?? true) ? "" : ", ")\(addr ?? "")")
                }
            }
        }
        
        guard let address = address else {
            let alert = LWAlertViewController()
            alert.title = "invalid payment address"
            alert.presentWithOkOnly(on: self)
            return
        }
        self.confirmAmount(amount: Int64(amount), fee: Int64(fee), address: address, name: request.commonName, memo: request.details.memo, isSecure: (valid && request.pkiType != .none))
    }
    
    func confirmSweep(_ string: String) {
        let privateKey = NSString(string: string)
        if !privateKey.isValidBitcoinPrivateKey() && !privateKey.isValidBitcoinBIP38Key() {
            return
        }
        
        let manager = BRWalletManager.sharedInstance()
        let alert = LWAlertViewController()
        alert.title = NSLocalizedString("checking private key balance...", comment: "")
        alert.presentWithOkOnly(on: self)
        manager?.sweepPrivateKey(string, withFee: true, completion: { transaction, error in
            if let error = error {
                let alert = LWAlertViewController()
                alert.message = (error as NSError).localizedDescription
                alert.presentWithOkOnly(on: self)
            } else if let transaction = transaction {
                guard let manager = manager, let request = self.protocolRequest else { return }
                let fee = transaction.standardFee
                var runningAmount = fee
                for amount in transaction.outputAmounts {
                    guard let amount = amount as? NSNumber else { continue }
                    runningAmount += amount.uint64Value
                }
                
                self.sweepTx = transaction
                
                let alert = LWAlertViewController()
                alert.message = NSLocalizedString("Send \(manager.string(forAmount: Int64(runningAmount)) ?? "0") (\(manager.localCurrencyString(forAmount: Int64(runningAmount)) ?? "0") from this private key into your wallet? The woodcoin network will receive a fee of \(manager.string(forAmount: Int64(fee)) ?? "0") (\(manager.localCurrencyString(forAmount: Int64(fee)) ?? "0").", comment: "")
                alert.addObject(.cancelButton)
                alert.addObject(.customPrimaryButton, text: "\(manager.string(forAmount: Int64(runningAmount)) ?? "0") (\(manager.localCurrencyString(forAmount: Int64(runningAmount)) ?? "0"))", action: UIAction { _ in
                    alert.dismiss(animated: true, completion: nil)
                    if self.tx == nil {
                        let alert = LWAlertViewController()
                        alert.title = "insufficient funds"
                        alert.presentWithOkOnly(on: self)
                    }
                })
                alert.present(on: self)
                
                NSLog("signing transaction")
                
                if !manager.wallet.sign(transaction) {
                    let alert = LWAlertViewController()
                    alert.title = "couldn't make payment"
                    alert.message = "error signing woodcoin transaction"
                    alert.presentWithOkOnly(on: self)
                }
                
                NSLog("signed transaction: \(NSString.hex(with: transaction.data) ?? "invalid")")
                
                BRPeerManager.sharedInstance().publishTransaction(transaction) { error in
                    if NSString(string: request.details.paymentURL).length > 0 {
                        return
                    }
                    
                    if let error = error {
                        let alert = LWAlertViewController()
                        alert.title = "couldn't make payment"
                        alert.message = "error signing woodcoin transaction: \(error.localizedDescription)"
                        alert.presentWithOkOnly(on: self)
                    } else {
                        let alert = LWAlertViewController()
                        alert.title = "sent!"
                        alert.presentWithOkOnly(on: self)
                    }
                }
                if NSString(string: request.details.paymentURL).length > 0 {
                    var refundAmount: UInt64 = 0
                    let refundScript = NSMutableData()
                    
                    refundScript.appendScriptPubKey(forAddress: manager.wallet.changeAddress)
                    
                    for amount in request.details.outputAmounts {
                        guard let amount = amount as? NSNumber else { return }
                        refundAmount += amount.uint64Value
                    }
                    
                    let payment = BRPaymentProtocolPayment(merchantData: request.details.merchantData, transactions: [transaction], refundToAmounts: [refundAmount], refundToScripts: [refundScript], memo: nil)
                    
                    NSLog("posting payment to: \(request.details.paymentURL ?? "")")
                    
                    BRPaymentRequest.post(payment, to: request.details.paymentURL, timeout: 20.0) { ack, error in
                        if let error = error, !manager.wallet.transactionIsRegistered(transaction.txHash) {
                            let alert = LWAlertViewController()
                            alert.message = error.localizedDescription
                            alert.presentWithOkOnly(on: self)
                        } else {
                            let alert = LWAlertViewController()
                            alert.title = "sent!"
                            alert.presentWithOkOnly(on: self)
                            
                            if let error = error {
                                NSLog(error.localizedDescription)
                            }
                        }
                    }
                }
            } else {
                self.reset()
            }
        })
    }
    
    func confirmAmount(amount: Int64, fee: Int64, address: String, name: String, memo: String, isSecure: Bool) {
        guard let manager = BRWalletManager.sharedInstance() else {
            let alert = LWAlertViewController()
            alert.message = "failed to confirm amount"
            alert.presentWithOkOnly(on: self)
            return
        }
        let amountString = "\(manager.string(forAmount: amount) ?? "0") (\(manager.localCurrencyString(forAmount: amount) ?? "0"))"
        var message = (isSecure && !name.isEmpty) ? "\\xF0\\x9F\\x94\\x92 " : ""
        
        if !isSecure, (self.protocolRequest?.errorMessage.isEmpty ?? false) != false {
            message.append("\\xE2\\x9D\\x8C ")
        }
        if !name.isEmpty {
            message.append(name.sanitized())
        }
        if !isSecure && message.isEmpty {
            message.append(NSString.base58(with: NSString(string: address).base58ToData()))
        }
        if !memo.isEmpty {
            message.append("\n\n\(memo.sanitized())")
        }
        
        message.append("\n\n\(manager.string(forAmount: amount - fee) ?? "0") (\(manager.localCurrencyString(forAmount: amount - fee) ?? "0"))")
        
        if fee > 0 {
            message.append(NSLocalizedString("\nwoodcoin network fee +\(manager.string(forAmount: fee) ?? "0") (\(manager.localCurrencyString(forAmount: fee) ?? "0"))", comment: ""))
        }
        
        self.okAddress = nil
        
        let alert = LWAlertViewController()
        alert.title = "confirm payment"
        alert.addObject(.cancelButton)
        alert.addObject(.customPrimaryButton, text: amountString, action: UIAction { _ in
            
            guard let transaction = self.tx else {
                let alert = LWAlertViewController()
                alert.title = "insufficient funds"
                alert.presentWithOkOnly(on: self)
                return
            }
            
            NSLog("signing transaction")
            
            if !manager.wallet.sign(transaction) {
                let alert = LWAlertViewController()
                alert.title = "couldn't make payment"
                alert.message = "error signing woodcoin transaction"
                alert.presentWithOkOnly(on: self)
                return
            }
            
            NSLog("signed transaction: \(NSString.hex(with: transaction.data) ?? "invalid")")
            
            guard let request = self.protocolRequest else { return }
            BRPeerManager.sharedInstance().publishTransaction(transaction) { error in
                if NSString(string: request.details.paymentURL).length > 0 {
                    return
                }
                
                if let error = error {
                    let alert = LWAlertViewController()
                    alert.title = "couldn't make payment"
                    alert.message = "error signing woodcoin transaction: \(error.localizedDescription)"
                    alert.presentWithOkOnly(on: self)
                } else {
                    let alert = LWAlertViewController()
                    alert.title = "sent!"
                    alert.presentWithOkOnly(on: self)
                    self.reset()
                }
            }
            
            if !request.details.paymentURL.isEmpty {
                var refundAmount: UInt64 = 0
                let refundScript: NSMutableData = .init()
                
                refundScript.appendScriptPubKey(forAddress: manager.wallet.changeAddress)
                
                for amount in request.details.outputAmounts {
                    guard let amount = amount as? NSNumber else { continue }
                    refundAmount += amount.uint64Value
                }
                
                let payment = BRPaymentProtocolPayment(merchantData: request.details.merchantData, transactions: [transaction], refundToAmounts: [refundAmount], refundToScripts: [refundScript], memo: nil)
                
                NSLog("posting payment to: \(request.details.paymentURL ?? "invalid")")
                
                BRPaymentRequest.post(payment, to: request.details.paymentURL, timeout: 20.0) { ack, error in
                    if let error = error, !manager.wallet.transactionIsRegistered(transaction.txHash) {
                        let alert = LWAlertViewController()
                        alert.message = error.localizedDescription
                        alert.presentWithOkOnly(on: self)
                    } else {
                        let alert = LWAlertViewController()
                        alert.title = "sent!"
                        alert.presentWithOkOnly(on: self)
                        
                        self.reset()
                        
                        if let error = error {
                            NSLog(error.localizedDescription)
                        }
                    }
                }
            }
        })
        alert.present(on: self)
    }
}

// MARK: BRAmount Delegate
extension LWAccountViewController: BRAmountViewControllerDelegate {
    func amountViewController(_ amountViewController: BRAmountViewController!, selectedAmount amount: UInt64) {
        if let request = amountViewController.info as? BRPaymentProtocolRequest {
            self.protoReqAmount = amount
            confirmProtocolRequest(request)
        } else if let request = amountViewController.info as? BRPaymentRequest {
            request.amount = amount
            complete(request)
        }
    }
}

// MARK: AVCapture Meta Delegate
extension LWAccountViewController: AVCaptureMetadataOutputObjectsDelegate {
    func presentScanner() {
        guard let scanner = UIStoryboard.inObjC.viewController(for: "ScanViewController") as? BRScanViewController else {
            let alert = LWAlertViewController()
            alert.title = "failed to present scanner"
            alert.presentWithOkOnly(on: self)
            return
        }
        scanner.delegate = self
        scanController = scanner
        present(scanController!, animated: true, completion: nil)
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        for object in metadataObjects {
            guard let object = object as? AVMetadataMachineReadableCodeObject,
                  object.type == .qr,
                    let request = BRPaymentRequest(string: object.stringValue) else { continue }
            let nsstring = NSString(string: object.stringValue ?? "")
            if !request.isValid, !nsstring.isValidBitcoinPrivateKey(), !nsstring.isValidBitcoinBIP38Key() {
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(resetQR), object: nil)
                self.scanController?.cameraGuide.image = UIImage(named: "cameraguide-red")
                self.scanController?.message.text = "not a valid woodcoin address\n\(request.paymentAddress ?? "[---]")"
                perform(#selector(resetQR), with: nil, afterDelay: 0.35)
            } else {
                scanController?.cameraGuide.image = UIImage(named: "cameraguide-green")
                scanController?.stop()
                
                if !request.r.isEmpty {
                    BRPaymentRequest.fetch(request.r, timeout: 5.0) { req, error in
                        if let error = error {
                            request.r = nil
                            if !request.isValid {
                                let alert = LWAlertViewController()
                                alert.title = "couldn't make payment"
                                alert.message = error.localizedDescription
                                alert.presentWithOkOnly(on: self)
                            }
                            
                            DispatchQueue.main.async {
                                self.complete(request)
                                self.resetQR()
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.confirmProtocolRequest(req)
                                self.resetQR()
                            }
                        }
                    }
                } else {
                    complete(request)
                    resetQR()
                }
            }
        }
    }
    
    @objc func resetQR() {
        scanController?.message.text = nil
        scanController?.cameraGuide.image = UIImage(named: "cameraguide")
    }
}

extension String {
    func sanitized() -> String {
        let string = self as NSString
        CFStringTransform(string as! NSMutableString, nil, kCFStringTransformToUnicodeName, false)
        return String(string)
    }
}

extension UIStoryboard {
    @objc static var inSwift: UIStoryboard {
        UIStoryboard(name: "Main_inSwift", bundle: nil)
    }
    
    @objc static var inObjC: UIStoryboard {
        UIStoryboard(name: "Main", bundle: nil)
    }
    
    @objc func viewController(for identifier: String) -> UIViewController {
        instantiateViewController(withIdentifier: identifier)
    }
}

var sharedAlert: LWAlertViewController?

extension UITableView {
    var alert: LWAlertViewController? {
        get {
            sharedAlert
        }
        set {
            sharedAlert = newValue
        }
    }
}
