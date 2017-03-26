//
//  RawDataHandler.swift
//  Flow
//
//  Created by Oliver Howden on 16/3/17.
//  Copyright © 2017 Oliver Howden. All rights reserved.
//

import Foundation

var k = GlobalConstants()
let openBCIUtils = OpenBCIUtils()
let myNotificationKey = "com.sigflow.notificationKey"
let bluetooth = BluetoothHandler()

struct Options {
    var debug: Bool = false
    var nobleAutoStart: Bool = true
    var nobleScanOnPowerOn: Bool = true
    var sendCounts: Bool = false
    var simulate: Bool = false
    var simulatorBoardFailure: Bool = false
    var simulatorHasAccelerometer: Bool = true
    var simulatorInternalClockDrift: Int = 0
    var simulatorInjectAlpha: Bool = true
    var simulatorInjectLineNoise = [k.obciSimulatorLineNoiseHz60, k.obciSimulatorLineNoiseHz50, k.obciSimulatorLineNoiseNone]
    var simulatorSampleRate: Int = 200
    var verbose: Bool = false
}

struct Sample {
    let sampleNumber: Int
    let timeStamp: Double
    var channelData: [Int32]?
    var accelData: [Double]?
}

struct Output {
    let channelNumber: Int
    var impedanceValue: Int
}

struct DataHandler {
    var options = Options()
    //    /** Private Properties (keep alphabetical) */
    private var accelArray:[Double] = [0, 0, 0]
    //    private var connected = false
    private var decompressedSamples: [[Int32]] = [[0],[0],[0]]
    private var decompressedDeltas: [[Int32]] = []
    private var receivedDeltas: [[Int32]] = []
    
    private var droppedPacketCounter = 0
    private var firstPacket = true
    private var lastPacket: Data?
    //    private var localName = nil
    private var multiPacketBuffer: Data?
    private var packetCounter = GlobalConstants.obciGanglionByteId18Bit.max.rawValue
    //    private var peripheral = nil
    //    private var rfduinoService = nil
    //    private var receiveCharacteristic = nil
    //    private var scanning = false
    //    private var sendCharacteristic = nil
    private var streaming = false
    //
    /** Public Properties (keep alphabetical) */
    //    private var peripheralArray = []
    //    private var ganglionPeripheralArray = []
    //    private var previousPeripheralArray = []
    //    private var manualDisconnect = false
    //
    
    init() {
        for i in 0..<3{
            decompressedSamples[i] = [0, 0, 0, 0]
        }
    }
    
    func printSampleToConsole(sample: Sample){
        print(sample.sampleNumber)
        for i in 0..<k.obciNumberOfChannelsGanglion{
            print("Channel \(i + 1): \(sample.channelData?[i]) Volts")
        }
    }
    
    func interpret24bitAsInt32(byteArray: Data, index: Int) -> Int32 {
        let i1 = UInt32((0xFF & byteArray[index])) << UInt32(16)
        let i2 = UInt32((0xFF & byteArray[index + 1])) << UInt32(8)
        let i3 = UInt32((0xFF & byteArray[index + 2]))
        
        var newInt:UInt32 = (i1|i2|i3)
        if ((newInt & 0x00800000) > 0) {
            newInt |= 0xFF000000;
        } else {
            newInt &= 0x00FFFFFF;
        }
        return Int32(newInt);
    }
    
    //Process an uncompressed packet of data
    mutating func processUncompressedData(data: Data){
        var start = 1
        
        //Reset the packet counter back to zero
        packetCounter = GlobalConstants.obciGanglionByteId18Bit.max.rawValue //Used to find dropped packets
        for i in 0..<4 {
            decompressedSamples[0][i] = interpret24bitAsInt32(byteArray: data, index: start)
            start += 3
        }
        let newSample = buildSample(sampleNumber: 0,rawData: decompressedSamples[0], accelData: nil)
        printSampleToConsole(sample: newSample)
        let sendableSample = [k.obciEmitterSample:newSample]
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: k.obciEmitterSample), object: nil, userInfo: sendableSample)
        
        //    this.emit(k.OBCIEmitterSample, newSample);
        
    }
    
    //The default route when a ByteID is not recognised
    func processOtherData(data: Data){
        openBCIUtils.debugBytes(prefix: "OtherData <<<", data: data)
    }
    
    //Checks for dropped packets
    mutating func processRouteSampleData(data: Data){
        if (Int(data[0]) == k.obciGanglionByteIdUncompressed){
            processUncompressedData(data: data)
        }
        else {
            processCompressedData(data: data)
        }
    }
    
    mutating func processSampleData(data: Data){
        let curByteID = Int(data[0])
        let difByteID = curByteID - packetCounter
        
        if firstPacket {
            firstPacket = false
            processRouteSampleData(data: data)
            return
        }
        
        //Wrap around situation
        if (difByteID < 0) {
            if (packetCounter <= GlobalConstants.obciGanglionByteId18Bit.max.rawValue){
                if (packetCounter == GlobalConstants.obciGanglionByteId18Bit.max.rawValue){
                    if (curByteID != k.obciGanglionByteIdUncompressed){
                        droppedPacket(curByteID - 1)
                    }
                }
                else {
                    var tempCounter = packetCounter + 1
                    while (tempCounter <= GlobalConstants.obciGanglionByteId18Bit.max.rawValue){
                        droppedPacket(tempCounter)
                        tempCounter += 1
                    }
                }
            }
            else if (packetCounter == GlobalConstants.obciGanglionByteId19Bit.max.rawValue){
                if (curByteID != k.obciGanglionByteIdUncompressed){
                    droppedPacket(curByteID - 1)
                }
            }
            else {
                var tempCounter = packetCounter + 1
                while (tempCounter <= GlobalConstants.obciGanglionByteId19Bit.max.rawValue){
                    droppedPacket(tempCounter)
                    tempCounter += 1
                }
            }
        }
        else if (difByteID > 1) {
            if (packetCounter == k.obciGanglionByteIdUncompressed && curByteID == GlobalConstants.obciGanglionByteId19Bit.min.rawValue) {
                processRouteSampleData(data: data)
                return
            }
                
            else {
                var tempCounter = packetCounter + 1
                while (tempCounter < curByteID){
                    droppedPacket(tempCounter)
                    tempCounter += 1
                }
                
            }
        }
        processRouteSampleData(data: data)
    }
    
    mutating func droppedPacket(_ droppedPacketNumber: Int){
        //  this.emit(k.OBCIEmitterDroppedPacket, [droppedPacketNumber]);
        
        let sendableSample = [k.obciEmitterDroppedPacket:droppedPacketNumber]
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: k.obciEmitterDroppedPacket), object: nil, userInfo: sendableSample)
        droppedPacketCounter += 1
    }
    
    mutating func resetDroppedPacketSystem(){
        packetCounter = -1
        firstPacket = true
        droppedPacketCounter = 0
    }
    
    // Adds the `data` buffer to the multi packet buffer and emits the buffer as 'message'
    mutating func processMultiBytePacketStop(data: Data){
        processMultiBytePacket(data: data)
        //this.emit(k.OBCIEmitterMessage, this._multiPacketBuffer);
        
        let sendableSample = [k.obciEmitterMessage:multiPacketBuffer]
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: k.obciEmitterMessage), object: nil, userInfo: sendableSample)
        
        destroyMultiPacketBuffer()
    }
    
    mutating func processMultiBytePacket(data: Data){
        if(multiPacketBuffer != nil){
            
            var dataToAppend = Data()
            
            for i in (GlobalConstants.obciGanglionPacket19Bit.dataStart.rawValue)...(GlobalConstants.obciGanglionPacket19Bit.dataStop.rawValue){
                dataToAppend[i - 1] = data[i]
            }
            multiPacketBuffer!.append(dataToAppend)
        }
        else {
            multiPacketBuffer = Data()
            var dataToAppend = Data()
            var tempCounter = 0
            
            for i in (GlobalConstants.obciGanglionPacket19Bit.dataStart.rawValue)...(GlobalConstants.obciGanglionPacket19Bit.dataStop.rawValue){
                dataToAppend[tempCounter] = data[i]
                tempCounter += 1
            }
            multiPacketBuffer!.append(dataToAppend)
        }
    }
    
    //Process a compressed packet of data
    mutating func processCompressedData(data:Data){
        packetCounter = Int(data[0])
        
        //Decompress buffer into array
        if (packetCounter <= GlobalConstants.obciGanglionByteId18Bit.max.rawValue){
            
            var tempCounter = 0
            var slicedData = Data()
            
            for i in (GlobalConstants.obciGanglionPacket18Bit.dataStart.rawValue)...(GlobalConstants.obciGanglionPacket18Bit.dataStop.rawValue){
                slicedData[tempCounter] = data[i]
                tempCounter += 1
            }
            
            decompressSamples(decompressDeltas18Bit(from: slicedData))
            switch (packetCounter % 10) {
            case k.obciGanglionAccelAxisX:
                accelArray[0] = options.sendCounts ? Double(data[GlobalConstants.obciGanglionPacket18Bit.auxByte.rawValue - 1]) : Double(data[GlobalConstants.obciGanglionPacket18Bit.auxByte.rawValue - 1]) * k.obciGanglionAccelScaleFactor
            case k.obciGanglionAccelAxisY:
                accelArray[1] = options.sendCounts ? Double(data[GlobalConstants.obciGanglionPacket18Bit.auxByte.rawValue - 1]) : Double(data[GlobalConstants.obciGanglionPacket18Bit.auxByte.rawValue - 1]) * k.obciGanglionAccelScaleFactor
            case k.obciGanglionAccelAxisZ:
                accelArray[2] = options.sendCounts ? Double(data[GlobalConstants.obciGanglionPacket18Bit.auxByte.rawValue - 1]) : Double(data[GlobalConstants.obciGanglionPacket18Bit.auxByte.rawValue - 1]) * k.obciGanglionAccelScaleFactor
            default:
                break
            }
            
            let sample1 = buildSample(sampleNumber: packetCounter * 2 - 1, rawData: decompressedSamples[1], accelData: accelArray)
            //      printSampleToConsole(sample: sample1)
            //    this.emit(k.OBCIEmitterSample, sample1);
            
            let sendableSample1 = [k.obciEmitterSample:sample1]
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: k.obciEmitterSample), object: nil, userInfo: sendableSample1)
            
            let sample2 = buildSample(sampleNumber: packetCounter * 2, rawData: decompressedSamples[2], accelData: accelArray)
            let sendableSample2 = [k.obciEmitterSample:sample2]
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: k.obciEmitterSample), object: nil, userInfo: sendableSample2)
            
            printSampleToConsole(sample: sample2)
            //    this.emit(k.OBCIEmitterSample, sample2);
            
        }
        else {
            var tempCounter = 0
            var slicedData = Data()
            for i in (GlobalConstants.obciGanglionPacket19Bit.dataStart.rawValue)...(GlobalConstants.obciGanglionPacket19Bit.dataStop.rawValue){
                slicedData[tempCounter] = data[i]
                tempCounter += 1
            }
            decompressSamples(decompressDeltas19Bit(from: slicedData))
            
            let sample1 = buildSample(sampleNumber: (packetCounter - 100) * 2 - 1, rawData: decompressedSamples[1], accelData: nil)
            printSampleToConsole(sample: sample1)
            //    this.emit(k.OBCIEmitterSample, sample1);
            
            let sendableSample1 = [k.obciEmitterSample:sample1]
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: k.obciEmitterSample), object: nil, userInfo: sendableSample1)
            
            let sample2 = buildSample(sampleNumber: (packetCounter - 100) * 2, rawData: decompressedSamples[2], accelData: nil)
            
            let sendableSample2 = [k.obciEmitterSample:sample2]
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: k.obciEmitterSample), object: nil, userInfo: sendableSample2)
            
            //    this.emit(k.OBCIEmitterSample, sample2);
            printSampleToConsole(sample: sample2)
        }
        
        //Rotate the 0 position for next time
        for i in 0..<k.obciNumberOfChannelsGanglion {
            decompressedSamples[0][i] = decompressedSamples[2][i]
        }
    }
    
    
    //Route incomming data to proper functions
    mutating func processBytes(data: Data){
        if (options.debug) {
            openBCIUtils.debugBytes(prefix: "<<<", data: data)
        }
        lastPacket = data
        let byteId = Int(data[0])
        if (byteId <= GlobalConstants.obciGanglionByteId19Bit.max.rawValue){
            processSampleData(data: data)
        }
        else{
            switch byteId {
            case k.obciGanglionByteIdMultiPacket:
                processMultiBytePacket(data: data)
            case k.obciGanglionByteIdMultiPacketStop:
                processMultiBytePacketStop(data: data)
            case k.obciGanglionByteIdImpedanceChannel1,k.obciGanglionByteIdImpedanceChannel2,k.obciGanglionByteIdImpedanceChannel3,k.obciGanglionByteIdImpedanceChannel4,k.obciGanglionByteIdImpedanceChannelReference:
                processImpedanceData(data: data)
            default:
                processOtherData(data: data)
            }
        }
    }
    
    func buildSample(sampleNumber: Int, rawData: [Int32], accelData: [Double]?) -> Sample {
        var sample = Sample(sampleNumber: sampleNumber, timeStamp: Date().timeIntervalSince1970, channelData: nil, accelData: accelData)
        if options.sendCounts {
            sample.channelData = rawData
        }
        else {
            sample.channelData = []
            for j in 0..<k.obciNumberOfChannelsGanglion {
                sample.channelData?.append(Int32(Double(rawData[j]) * k.obciGanglionScaleFactorPerCountVolts))
                
            }
        }
        return sample
    }
    
    
    func channelOn(channelNumber: Int){
        switch channelNumber {
        case 1:
            writeToBoard(command: k.obciChannelOn1)
        case 2:
            writeToBoard(command: k.obciChannelOn2)
        case 3:
            writeToBoard(command: k.obciChannelOn3)
        case 4:
            writeToBoard(command: k.obciChannelOn4)
        default:
            break
        }
        print("sent command to turn channel \(channelNumber) on")
    }
    
    func channelOff(channelNumber: Int){
        switch channelNumber {
        case 1:
            writeToBoard(command: k.obciChannelOff1)
        case 2:
            writeToBoard(command: k.obciChannelOff2)
        case 3:
            writeToBoard(command: k.obciChannelOff3)
        case 4:
            writeToBoard(command: k.obciChannelOff4)
        default:
            break
        }
        print("sent command to turn channel \(channelNumber) on")
    }
    
    //Converts a string to buffer and sends it to the board
    func writeToBoard(command: String){
        let dataToSend = command.data(using: String.Encoding.utf8)
        bluetooth.sendData(data: dataToSend!)
        print("sent \(command) to board")
    }
    
    
    
    // Takes the board out of synthetic data generation mode. Must call streamStart still.
    func syntheticDisable(){
        writeToBoard(command: k.obciGanglionSyntheticDataDisable)
        
    }
    
    // Puts the board in synthetic data generation mode. Must call streamStart still
    func syntheticEnable(){
        writeToBoard(command: k.obciGanglionSyntheticDataEnable)
    }
    
    //Stops the board streaming
    mutating func streamStop(){
        if (isStreaming()){
            streaming = false
            writeToBoard(command: k.obciStreamStop)
        }
    }
    //Starts the board streaming
    mutating func streamStart(){
        if (isStreaming()){
            print("Already Streaming")
        }
        streaming = true
        writeToBoard(command: k.obciStreamStart)
        if (options.verbose) {
            print("Sent stream start command to board")
        }
    }
    
    mutating func disconnect(stopStreaming: Bool){
        if stopStreaming {
            if isStreaming() {
                if options.verbose {
                    print("Stop streaming")
                }
                streamStop()
            }
        }
    }
    
    func accelStop(){
        writeToBoard(command: k.obciAccelStop)
    }
    
    func accelStart(){
        writeToBoard(command: k.obciAccelStart)
    }
    
    mutating func destroyMultiPacketBuffer(){
        multiPacketBuffer?.removeAll()
    }
    
    func getMultiPacketBuffer() -> Data {
        return multiPacketBuffer!
    }
    
    func printRegisterSettings(){
        writeToBoard(command: k.obciMiscQueryRegisterSettings)
    }
    
    func impedanceStop(){
        writeToBoard(command: k.obciGanglionImpedanceStop)
    }
    
    func impedanceStart() {
        writeToBoard(command: k.obciGanglionImpedanceStart)
    }
    
    func isStreaming() -> Bool{
        return streaming
    }
    //Performs a soft reset
    func softReset(){
        writeToBoard(command: k.obciMiscSoftReset)
    }
    
    func sampleRate() -> Int {
        if options.simulate {
            return options.simulatorSampleRate
        }
        else{
            return k.obciSampleRate200
        }
    }
    
    // Process and emit an impedance value
    func processImpedanceData(data: Data){
        if (options.debug){
            openBCIUtils.debugBytes(prefix: "Impedance <<<", data: data)
        }
        let byteId = Int(data[0])
        var channelNumber = Int()
        switch byteId {
        case k.obciGanglionByteIdImpedanceChannel1:
            channelNumber = 1
        case k.obciGanglionByteIdImpedanceChannel2:
            channelNumber = 2
        case k.obciGanglionByteIdImpedanceChannel3:
            channelNumber = 3
        case k.obciGanglionByteIdImpedanceChannel4:
            channelNumber = 4
        case k.obciGanglionByteIdImpedanceChannelReference:
            channelNumber = 0
        default:
            break
        }
        
        var output = Output(channelNumber: channelNumber, impedanceValue: 0)
        
        var end = data.count
        var slicedData = Data()
        
        for i in 1...end{
            slicedData[i - 1] = data[i]
        }
        
        //This is surely going to cause problems
        while (Int(String(data: slicedData, encoding: .utf8)!) != nil && end != 0){
            slicedData.removeLast()
            end -= 1
        }
        
        if (end != 0) {
            var slicedData = Data()
            for i in 1...end{
                slicedData[i - 1] = data[i]
            }
            output.impedanceValue = Int(String(data: slicedData, encoding: .utf8)!)!
            let sendableSample = [k.obciEmitterImpedance:output]
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: k.obciEmitterImpedance), object: nil, userInfo: sendableSample)
            
            //  this.emit('impedance', output);
            
        }
    }
    
    
    func interpret16bitAsInt32(_ twoByteBuffer: [UInt8]) -> Float {
        var prefix:Int32 = 0;
        
        if (twoByteBuffer[0] > 127) {
            print("negative number")
            prefix = 65535; // 0xFFFF
        }
        let convertedNumber = (prefix << Int32(16)) | (Int32(twoByteBuffer[0]) << Int32(8)) | Int32(twoByteBuffer[1])
        
        return Float(convertedNumber)
    }
    
    func convert18bitAsInt32(_ threeByteBuffer: [UInt8]) -> Float {
        var prefix:Int32 = 0;
        
        if (threeByteBuffer[2] & 0x01 > 0) {
            print("Negative number")
            prefix = 0b11111111111111
            
        }
        let convertedNumber = (prefix << Int32(18)) | (Int32(threeByteBuffer[0]) << Int32(16)) | (Int32(threeByteBuffer[1]) << Int32(8)) | Int32(threeByteBuffer[2])
        return Float(convertedNumber)
    }
    
    
    func convert19bitAsInt32(_ threeByteBuffer: [UInt8]) -> Float {
        var prefix:Int32 = 0
        
        if (threeByteBuffer[2] & 0x01 > 0) {
            prefix = 0b11111111111111
            print("Negative")
        }
        // let convertedNumber = (prefix << 19) | (Int(threeByteBuffer[0]) << 16) | (Int(threeByteBuffer[1]) << 8) | Int(threeByteBuffer[2])
        
        return Float(prefix << Int32(19) | Int32(threeByteBuffer[0]) << Int32(16) | Int32(threeByteBuffer[1]) << 8 | Int32(threeByteBuffer[2]))
        
        // return Int(convertedNumber)
    }
    
    
    func decompressDeltas18Bit(from buffer: Data) -> [[Float]] {
        
        var receivedDeltas = [[Float]]()
        receivedDeltas = [[0, 0, 0, 0],
                          [0, 0, 0, 0]]
        
        // Sample 1 - Channel 1
        var miniBuf = [UInt8]()
        miniBuf = [
            (buffer[0] >> UInt8(6)),
            ((buffer[0] & 0x35) << 2) | (buffer[1] >> 6),
            ((buffer[1] & 0x35) << 2) | (buffer[2] >> 6)
        ]
        
        receivedDeltas[0][0] = convert18bitAsInt32(miniBuf)
        
        miniBuf.removeAll()
        
        // Sample 1 - Channel 2
        miniBuf = [
            (buffer[2] & 0x3F) >> 4,
            (buffer[2] << 4) | (buffer[3] >> 4),
            (buffer[3] << 4) | (buffer[4] >> 4)
        ]
        // miniBuf = new Buffer([(buffer[2] & 0x1F), buffer[3], buffer[4] >> 2]);
        receivedDeltas[0][1] = convert18bitAsInt32(miniBuf)
        
        miniBuf.removeAll()
        
        
        // Sample 1 - Channel 3
        miniBuf = [
            (buffer[4] & 0x0F) >> 2,
            (buffer[4] << 6) | (buffer[5] >> 2),
            (buffer[5] << 6) | (buffer[6] >> 2)
        ]
        
        receivedDeltas[0][2] = convert18bitAsInt32(miniBuf)
        
        miniBuf.removeAll()
        
        // Sample 1 - Channel 4
        miniBuf = [
            (buffer[6] & 0x03),
            buffer[7],
            buffer[8]
        ]
        receivedDeltas[0][3] = convert18bitAsInt32(miniBuf)
        
        miniBuf.removeAll()
        
        
        // Sample 2 - Channel 1
        miniBuf = [
            (buffer[9] >> 6),
            ((buffer[9] & 0x3F) << 2) | (buffer[10] >> 6),
            ((buffer[10] & 0x3F) << 2) | (buffer[11] >> 6)
        ]
        receivedDeltas[1][0] = convert18bitAsInt32(miniBuf)
        
        miniBuf.removeAll()
        
        // Sample 2 - Channel 2
        miniBuf = [
            (buffer[11] & 0x3F) >> 4,
            (buffer[11] << 4) | (buffer[12] >> 4),
            (buffer[12] << 4) | (buffer[13] >> 4)
        ]
        receivedDeltas[1][1] = convert18bitAsInt32(miniBuf)
        
        miniBuf.removeAll()
        
        // Sample 2 - Channel 3
        miniBuf = [
            (buffer[13] & 0x0F) >> 2,
            (buffer[13] << 6) | (buffer[14] >> 2),
            (buffer[14] << 6) | (buffer[15] >> 2)
        ]
        receivedDeltas[1][2] = convert18bitAsInt32(miniBuf);
        
        miniBuf.removeAll()
        
        // Sample 2 - Channel 4
        miniBuf = [(buffer[15] & 0x03), buffer[16], buffer[17]]
        receivedDeltas[1][3] = convert18bitAsInt32(miniBuf)
        
        return receivedDeltas;
    }
    
    func decompressDeltas19Bit(from buffer: Data) -> [[Float]] {
        
        var receivedDeltas = [[Float]]()
        receivedDeltas = [[0, 0, 0, 0],
                          [0, 0, 0, 0]]
        
        // Sample 1 - Channel 1
        var miniBuf = [UInt8]()
        miniBuf = [
            (buffer[0] >> UInt8(6)),
            ((buffer[0] & 0x35) << 2) | (buffer[1] >> 6),
            ((buffer[1] & 0x35) << 2) | (buffer[2] >> 6)
        ]
        
        receivedDeltas[0][0] = convert19bitAsInt32(miniBuf)
        
        // Sample 1 - Channel 1
        miniBuf = [
            (buffer[0] >> 5),
            ((buffer[0] & 0x1F) << 3) | (buffer[1] >> 5),
            ((buffer[1] & 0x1F) << 3) | (buffer[2] >> 5)
        ]
        receivedDeltas[0][0] = convert19bitAsInt32(miniBuf)
        
        // Sample 1 - Channel 2
        miniBuf = [
            (buffer[2] & 0x1F) >> 2,
            (buffer[2] << 6) | (buffer[3] >> 2),
            (buffer[3] << 6) | (buffer[4] >> 2)
        ]
        
        // miniBuf = new Buffer([(buffer[2] & 0x1F), buffer[3], buffer[4] >> 2]);
        receivedDeltas[0][1] = convert19bitAsInt32(miniBuf)
        
        // Sample 1 - Channel 3
        miniBuf = [
            ((buffer[4] & 0x03) << 1) | (buffer[5] >> 7),
            ((buffer[5] & 0x7F) << 1) | (buffer[6] >> 7),
            ((buffer[6] & 0x7F) << 1) | (buffer[7] >> 7)
        ]
        receivedDeltas[0][2] = convert19bitAsInt32(miniBuf)
        
        // Sample 1 - Channel 4
        miniBuf = [
            ((buffer[7] & 0x7F) >> 4),
            ((buffer[7] & 0x0F) << 4) | (buffer[8] >> 4),
            ((buffer[8] & 0x0F) << 4) | (buffer[9] >> 4)
        ]
        receivedDeltas[0][3] = convert19bitAsInt32(miniBuf)
        
        // Sample 2 - Channel 1
        miniBuf = [
            ((buffer[9] & 0x0F) >> 1),
            (buffer[9] << 7) | (buffer[10] >> 1),
            (buffer[10] << 7) | (buffer[11] >> 1)
        ]
        receivedDeltas[1][0] = convert19bitAsInt32(miniBuf)
        
        // Sample 2 - Channel 2
        miniBuf = [
            ((buffer[11] & 0x01) << 2) | (buffer[12] >> 6),
            (buffer[12] << 2) | (buffer[13] >> 6),
            (buffer[13] << 2) | (buffer[14] >> 6)
        ]
        receivedDeltas[1][1] = convert19bitAsInt32(miniBuf)
        
        // Sample 2 - Channel 3
        miniBuf = [
            ((buffer[14] & 0x38) >> 3),
            ((buffer[14] & 0x07) << 5) | ((buffer[15] & 0xF8) >> 3),
            ((buffer[15] & 0x07) << 5) | ((buffer[16] & 0xF8) >> 3)
        ]
        receivedDeltas[1][2] = convert19bitAsInt32(miniBuf)
        
        // Sample 2 - Channel 4
        miniBuf = [(buffer[16] & 0x07), buffer[17], buffer[18]]
        receivedDeltas[1][3] = convert19bitAsInt32(miniBuf)
        
        return receivedDeltas;
    }
    
    mutating func decompressSamples(_ receivedSamples: [[Float]]) {
        // add the delta to the previous value
        for i in 0..<3 {
            for j in 0..<4 {
                decompressedSamples[i][j] = decompressedSamples[i - 1][j] - receivedDeltas[i - 1][j]
            }
        }
    }
}
