//
//  ViewController.swift
//  Flow
//
//  Created by Oliver Howden on 15/3/17.
//  Copyright © 2017 Oliver Howden. All rights reserved.
//

import UIKit



class ViewController: UIViewController {
    var ganglion = DataHandler()
    var simblee = BluetoothController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        simblee.initialise()
    
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

