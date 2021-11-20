//
//  demofile.swift
//  loughwallet
//
//  Created by Erik Bean on 4/21/21.
//  Copyright © 2021 Aaron Voisine. All rights reserved.
//

import UIKit

class LWWelcomeController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Re-add Jailbreak checking
        
        if UIApplication.shared.isProtectedDataAvailable && BRWalletManager.sharedInstance()?.wallet != nil {
            performSegue(withIdentifier: "pin", sender: self)
        }
    }
    
    @IBAction func didTapNewWallet(_ sender: UIButton) {
        // show alert then segue to "account" if they do not want
        // to display their backup phrase, if they do, segue to
        // "backup". include that they can see their phrase
        // anytime from the account page
        performSegue(withIdentifier: "backup", sender: self)
    }
}
