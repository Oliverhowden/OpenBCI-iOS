//
//  ViewController.swift
//  Flow
//
//  Created by Oliver Howden on 15/3/17.
//  Copyright © 2017 Oliver Howden. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    var rdh = DataHandler()
    var ganglion = DataHandler()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(doThisWhenNotify),
                                               name: NSNotification.Name(rawValue: myNotificationKey),
                                               object: nil)
    }
    
    
    
    func doThisWhenNotify() {
        print("I've sent a spark!")
    }
    
    
    
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

