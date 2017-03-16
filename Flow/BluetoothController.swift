import Foundation
import CoreBluetooth

class BluetoothController: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var manager : CBCentralManager!
    var peripheral: CBPeripheral!
    let simbleeUuidConnect : CBUUID = CBUUID(string: "FE84")
    let simbleeUuidReceive : CBUUID = CBUUID(string: "2D30C082-F39F-4CE6-923F-3484EA480596")
    let simbleeUuidSend : CBUUID = CBUUID(string: "2D30C083-F39F-4CE6-923F-3484EA480596")
    let simbleeUuidDisconnect : CBUUID = CBUUID(string: "2D30C084-F39F-4CE6-923F-3484EA480596")
    let simbleeCBUUIDArray = [CBUUID(string: "FE84")]
    
    func initialise() {
        manager = CBCentralManager(delegate: self, queue: nil) // self refers to class: viewcontroller
        scanBLEDevices()
        
    }
    
    var peripherals:[CBPeripheral] = []
    // var parentView:MainViewController? = nil
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        // Here we check if the phone bluetooth is turned on. (poweredON = Bluetooth on in phone settings.)
        if central.state == CBManagerState.poweredOn {
            
            // Scan for bluetooth device (Must use nil, nil.)
            central.scanForPeripherals(withServices: simbleeCBUUIDArray, options: nil)
            print("HERE")
        } else {
            print("Bluetooth not available.")
        }
    }
    
    func streamData(data: Data){
        //      decompressedDeltas = decompressDeltas18Bit(from: data)
        //      decompressedSamples = decompressSamples(receivedDeltas: decompressedDeltas)
    }

    // MARK: BLE Scanning
    func scanBLEDevices() {
        manager?.scanForPeripherals(withServices: nil, options: nil)
        
        //stop scanning after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.stopScanForBLEDevices()
        }
    }
    
    func stopScanForBLEDevices() {
        manager?.stopScan()
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let device = (advertisementData as NSDictionary).object(forKey: CBAdvertisementDataLocalNameKey) as? NSString
        
        // If the device is "Simblee" assign it to our peripheral.
        if device?.contains("Simblee") == true {
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
                print("what the fuck?")
            }
            
            manager.connect(peripheral, options: nil)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if (characteristic.uuid.uuidString == simbleeUuidReceive.uuidString) {
            //Data recieved
            if(characteristic.value != nil) {
                let stringValue = String(data: characteristic.value!, encoding: String.Encoding.utf8)!
                streamData(data: characteristic.value!)
            }
        }
        
        func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            
            //pass reference to connected peripheral to parent view
            //   parentView?.mainPeripheral = peripheral
            //peripheral.delegate = parentView
            peripheral.discoverServices(nil)
            
            //set the manager's delegate view to parent so it can call relevant disconnect methods
            //manager?.delegate = parentView

            print("Connected to " +  peripheral.name!)
        }
        
        func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
            print(error!)
        }
        
    }
        
}

