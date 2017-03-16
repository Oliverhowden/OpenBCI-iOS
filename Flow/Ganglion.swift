//
//  Ganglion.swift
//  Flow
//
//  Created by Oliver Howden on 16/3/17.
//  Copyright © 2017 Oliver Howden. All rights reserved.
//

import Foundation

let impedance = false;
let accel = false;

class Ganglion {
    
    
    func initialise() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.newSampleReceived(_:)), name: NSNotification.Name(rawValue: k.obciEmitterSample), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.newMessageReceived(_:)), name: NSNotification.Name(rawValue: k.obciEmitterSample), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.newImpedanceReceived(_:)), name: NSNotification.Name(rawValue: k.obciEmitterSample), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.newDroppedPacket(_:)), name: NSNotification.Name(rawValue: k.obciEmitterSample), object: nil)
        
    }
    
    
    
    @objc func newSampleReceived(_ notification: NSNotification) {
        print("Sample Received")
        
        if let sample = notification.userInfo?[k.obciEmitterSample]  as? Sample {
            print(sample.sampleNumber)
            for i in 0..<k.obciNumberOfChannelsGanglion{
                print("Channel \(i + 1): \(sample.channelData?[i]) Volts")
            }
        }
    }
    
    @objc func newMessageReceived(_ notification: NSNotification) {
        //        print("Message Received")
        //
        //        if let packetNumber = notification.userInfo?[k.obciEmitterMessage]  as? Data {
        //            print("Dropped packet #:\(packetNumber)")
        //        }
    }
    
    @objc func newImpedanceReceived(_ notification: NSNotification) {
        print("Impedance Received")
        
        if let output = notification.userInfo?[k.obciEmitterImpedance]  as? Output {
            print("Channel Number: \(output.channelNumber) Impedance: \(output.impedanceValue)")
        }
    }
    @objc func newDroppedPacket(_ notification: NSNotification) {
        print("new Dropped Packet")
        
        if let packetNumber = notification.userInfo?[k.obciEmitterMessage]  as? Int {
            print("Dropped packet #:\(packetNumber)")
        }
    }
    
}
