import Foundation
import CoreBluetooth

class BluetoothHandler: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
 
    let simbleeUuidReceive : CBUUID = CBUUID(string: "2D30C082-F39F-4CE6-923F-3484EA480596")
    let simbleeUuidSend : CBUUID = CBUUID(string: "2D30C083-F39F-4CE6-923F-3484EA480596")
    let simbleeUuidDisconnect : CBUUID = CBUUID(string: "2D30C084-F39F-4CE6-923F-3484EA480596")
    let simbleeCBUUIDArray = [CBUUID(string: "FE84")]
    var sendToSimbleeCharacteristic:CBCharacteristic? = nil
    var receiveFromSimbleeCharacteristic:CBCharacteristic? = nil
    var processor = DataHandler()
    var peripherals:[CBPeripheral] = []
    let simbleeUuidConnect : CBUUID = CBUUID(string: "FE84")
    var manager : CBCentralManager!
    var peripheral: CBPeripheral!
    var mainPeripheral: CBPeripheral!
    func initialise() {
        manager = CBCentralManager(delegate: self, queue: nil) // self refers to class: viewcontroller
    }
    

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        // Here we check if the phone bluetooth is turned on. (poweredON = Bluetooth on in phone settings.)
        if central.state == CBManagerState.poweredOn {
            
            // Scan for bluetooth device (Must use nil, nil.)
            central.scanForPeripherals(withServices: simbleeCBUUIDArray, options: nil)
        } else {
            print("Bluetooth not available.")
        }
    }
    
    // MARK: BLE Scanning
    func scanBLEDevices() {
        manager?.scanForPeripherals(withServices: nil, options: nil)
        
        //stop scanning after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.manager?.stopScan()
        }
    }
    
    func sendData(data: Data){
        //        let helloWorld = "Hello World!"
        //        let dataToSend = helloWorld.data(using: String.Encoding.utf8)
        
        if (mainPeripheral != nil) {
            mainPeripheral?.writeValue(data, for: sendToSimbleeCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
        } else {
            print("Haven't discovered device yet")
            
        }
        
        func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
            let device = (advertisementData as NSDictionary).object(forKey: CBAdvertisementDataLocalNameKey) as? NSString
            
            // If the device is "Simblee" assign it to our peripheral.
            if device?.contains("Ganglion") == true {
                self.manager.stopScan()
                self.peripheral = peripheral
                self.peripheral.delegate = self
                
                print(peripheral.identifier)
                print(RSSI)
                print(device ?? "")
                print(advertisementData)
                
                if let services = peripheral.services {
                    for service in services {
                        print("service: ")
                        print(service)
                    }
                } else {
                    print("Ganglion not found")
                }
                manager.connect(peripheral, options: nil)
            }
        }
        
        func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
            if (service.uuid.uuidString == simbleeUuidConnect.uuidString) {
                for characteristic in service.characteristics! {
                    switch (characteristic.uuid.uuidString){
                        
                    case simbleeUuidSend.uuidString:
                        sendToSimbleeCharacteristic = characteristic
                        //Set Notify is useful to read incoming data async
                        self.peripheral.setNotifyValue(true, for: characteristic)
                        
                    case simbleeUuidReceive.uuidString:
                        receiveFromSimbleeCharacteristic = characteristic
                        
                        self.peripheral.setNotifyValue(true, for: characteristic)
                    default: break
                    }
                }
            }
        }
        
        
        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            if (characteristic.uuid.uuidString == simbleeUuidReceive.uuidString) {
                //Data recieved
                if(characteristic.value != nil) {
                  //  let stringValue = String(data: characteristic.value!, encoding: String.Encoding.utf8)!
                    processor.processBytes(data: characteristic.value!)
                }
            }
        }
        
        func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            
            mainPeripheral = peripheral
            peripheral.delegate = self
            peripheral.discoverServices(nil)
            manager?.delegate = self
            
            print("Connected to " +  peripheral.name!)
        }
        
        func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
            print(error!)
        }
        
    }
    
    
}
