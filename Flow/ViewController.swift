//
//  ViewController.swift
//  Flow
//
//  Created by Oliver Howden on 15/3/17.
//  Copyright © 2017 Oliver Howden. All rights reserved.
//

import UIKit
import CoreBluetooth
import Charts

class ViewController: UIViewController, ChartViewDelegate {
    
    
    @IBOutlet weak var lineChartView: LineChartView!
    var processor = DataHandler()
    var bluetooth = BluetoothHandler()
    var notifier = Ganglion()
    var months: [String]!
    var timer: Timer?
    let myNotificationKey = "com.sigflow.notificationKey"
    var i = 0
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
 //       NotificationCenter.default.addObserver(self, selector: #selector(self.newSampleReceived(_:)), name: NSNotification.Name(rawValue: k.obciEmitterSample), object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(self.newMessageReceived(_:)), name: NSNotification.Name(rawValue: k.obciEmitterSample), object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(self.newImpedanceReceived(_:)), name: NSNotification.Name(rawValue: k.obciEmitterSample), object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(self.newDroppedPacket(_:)), name: NSNotification.Name(rawValue: k.obciEmitterSample), object: nil)
//        

        
        //charts
        self.lineChartView.delegate = self
        let set_a: LineChartDataSet = LineChartDataSet(values: [ChartDataEntry](), label: "a")
        set_a.drawCirclesEnabled = false
        set_a.setColor(UIColor.blue)
        
        
        //   self.lineChartView.data = LineChartData(xVals: [String](), dataSets: [set_a, set_b])
        
        self.lineChartView.data = LineChartData(dataSet: set_a)
        
     //   timer = Timer.scheduledTimer(timeInterval: 0.010, target:self, selector: #selector(ViewController.updateCounter), userInfo: nil, repeats: true)
    }
    
    
    
    
    
    @IBAction func startStream(_ sender: UIButton) {
        processor.streamStart()
    }
    @IBAction func stopStream(_ sender: UIButton) {
        processor.streamStop()
    }
    @IBAction func startAccel(_ sender: Any) {
        processor.accelStart()
    }
    @IBAction func stopAccel(_ sender: Any) {
        processor.accelStop()
    }
    
    
    
    @objc func newSampleReceived(_ notification: NSNotification) {
        print("Sample Received")
        //
        //        if let sample = notification.userInfo?[k.obciEmitterSample]  as? Sample {
        //            print(sample.sampleNumber)
        //            for i in 0..<k.obciNumberOfChannelsGanglion{
        //                print("Channel \(i + 1): \(sample.channelData?[i]) Volts")
        //
        //            }
        
        
        if let sample = notification.userInfo?[k.obciEmitterSample]  as? Sample {
            let chartData = ChartDataEntry(x: Double(sample.sampleNumber), y:Double(sample.channelData![0]))            
            self.lineChartView.data?.addEntry(chartData, dataSetIndex: sample.sampleNumber)
      //      self.lineChartView.data?.addXValue(String(sample.sampleNumber))
            
            self.lineChartView.setVisibleXRange(minXRange: Double(1), maxXRange: Double(50))
            self.lineChartView.notifyDataSetChanged()
            self.lineChartView.moveViewToX(Double(sample.sampleNumber))
            i += 1
        }
    }
    
}

