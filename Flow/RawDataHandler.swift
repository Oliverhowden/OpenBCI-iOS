//
//  RawDataHandler.swift
//  Flow
//
//  Created by Oliver Howden on 16/3/17.
//  Copyright © 2017 Oliver Howden. All rights reserved.
//

import Foundation

var k = BoardCommands()
let openBCIUtils = OpenBCIUtils()

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
    let sampleNummber: Int
    let timeStamp: Double
    var channelData: [Int]?
}


struct DataHandler {

    var options = Options()
    
    //    /** Private Properties (keep alphabetical) */
    private var accelArray:[Double] = [0, 0, 0]
    //    private var connected = false
    private var decompressedSamples: [[Int]] = [[0],[0],[0]]
    
    private var droppedPacketCounter = 0
    private var firstPacket = true
    //    private var lastDroppedPacket = nil
    private var lastPacket: Data?
    //    private var localName = nil
    private var multiPacketBuffer: Data?
    private var packetCounter = BoardCommands.obciGanglionByteId18Bit.max.rawValue
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
    
    
    init() {
        for i in 0..<4{
            decompressedSamples[i] = [0, 0, 0, 0]
        }
    }
    
    func interpret24bitAsInt32(byteArray: Data, index: Int) -> Int {
        let i1 = UInt32((0xFF & byteArray[index])) << UInt32(16)
        let i2 = UInt32((0xFF & byteArray[index + 1])) << UInt32(8)
        let i3 = UInt32((0xFF & byteArray[index + 2]))
        
        var newInt:UInt32 = (i1|i2|i3)
        if ((newInt & 0x00800000) > 0) {
            newInt |= 0xFF000000;
        } else {
            newInt &= 0x00FFFFFF;
        }
        return Int(newInt);
    }
    
    
    
    

    //Process an uncompressed packet of data
    mutating func processUncompressedData(data: Data){
        var start = 1
        
        //Reset the packet counter back to zero
        packetCounter = BoardCommands.obciGanglionByteId18Bit.max.rawValue //Used to find dropped packets
        for i in 0..<4 {
            decompressedSamples[0][i] = interpret24bitAsInt32(byteArray: data, index: start)
            start += 3
        }
        let newSample = buildSample(sampleNumber: 0,rawData: decompressedSamples[0])
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
            if (packetCounter <= BoardCommands.obciGanglionByteId18Bit.max.rawValue){
                if (packetCounter == BoardCommands.obciGanglionByteId18Bit.max.rawValue){
                    if (curByteID != k.obciGanglionByteIdUncompressed){
                        droppedPacket(curByteID - 1)
                    }
                }
                else {
                    var tempCounter = packetCounter + 1
                    while (tempCounter <= BoardCommands.obciGanglionByteId18Bit.max.rawValue){
                        droppedPacket(tempCounter)
                        tempCounter += 1
                    }
                }
            }
            else if (packetCounter == BoardCommands.obciGanglionByteId19Bit.max.rawValue){
                if (curByteID != k.obciGanglionByteIdUncompressed){
                    droppedPacket(curByteID - 1)
                }
            }
            else {
                var tempCounter = packetCounter + 1
                while (tempCounter <= BoardCommands.obciGanglionByteId19Bit.max.rawValue){
                    droppedPacket(tempCounter)
                    tempCounter += 1
                }
            }
        }
        else if (difByteID > 1) {
            if (packetCounter == k.obciGanglionByteIdUncompressed && curByteID == BoardCommands.obciGanglionByteId19Bit.min.rawValue) {
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
        droppedPacketCounter += 1
    }
    
    mutating func resetDroppedPacketSystem(){
        packetCounter = -1
        firstPacket = true
        droppedPacketCounter = 0
    }
    
    /**
     * Adds the `data` buffer to the multi packet buffer and emits the buffer as 'message'
     * @param data {Buffer}
     *  The multi packet stop buffer.
     * @private
     */
    mutating func processMultiBytePacketStop(data: Data){
        processMultiBytePacket(data: data)
        //this.emit(k.OBCIEmitterMessage, this._multiPacketBuffer);
        destroyMultiPacketBuffer()
    }
    
    mutating func processMultiBytePacket(data: Data){
        if(multiPacketBuffer != nil){
            var dataToAppend = Data()
            for i in (BoardCommands.obciGanglionPacket19Bit.dataStart.rawValue)...(BoardCommands.obciGanglionPacket19Bit.dataStop.rawValue){
                dataToAppend[i - 1] = data[i]
            }
            multiPacketBuffer!.append(dataToAppend)
        }
        else {
            multiPacketBuffer = Data()
            var dataToAppend = Data()
            var tempCounter = 0
            for i in (BoardCommands.obciGanglionPacket19Bit.dataStart.rawValue)...(BoardCommands.obciGanglionPacket19Bit.dataStop.rawValue){
                dataToAppend[tempCounter] = data[i]
                tempCounter += 1
            }
            multiPacketBuffer!.append(dataToAppend)
        }
    }
    
    
    
    
    /**
     * Process an compressed packet of data.
     * @param data {Buffer}
     *  Data packet buffer from noble.
     * @private
     */
    mutating func processCompressedData(data:Data){
        packetCounter = Int(data[0])
        
        //Decompress buffer into array
        if (packetCounter <= BoardCommands.obciGanglionByteId18Bit.max.rawValue){
            var tempCounter = 0
            var slicedData = Data()
            for i in (BoardCommands.obciGanglionPacket18Bit.dataStart.rawValue)...(BoardCommands.obciGanglionPacket18Bit.dataStop.rawValue){
                slicedData[tempCounter] = data[i]
                tempCounter += 1
            }
            decompressSamples(decompressDeltas18Bit(slicedData))
            switch (packetCounter % 10) {
            case k.obciGanglionAccelAxisX:
                accelArray[0] = options.sendCounts ? Double(data[BoardCommands.obciGanglionPacket18Bit.auxByte.rawValue - 1]) : Double(data[BoardCommands.obciGanglionPacket18Bit.auxByte.rawValue - 1]) * k.obciGanglionAccelScaleFactor
            case k.obciGanglionAccelAxisY:
                accelArray[1] = options.sendCounts ? Double(data[BoardCommands.obciGanglionPacket18Bit.auxByte.rawValue - 1]) : Double(data[BoardCommands.obciGanglionPacket18Bit.auxByte.rawValue - 1]) * k.obciGanglionAccelScaleFactor
            case k.obciGanglionAccelAxisZ:
                accelArray[2] = options.sendCounts ? Double(data[BoardCommands.obciGanglionPacket18Bit.auxByte.rawValue - 1]) : Double(data[BoardCommands.obciGanglionPacket18Bit.auxByte.rawValue - 1]) * k.obciGanglionAccelScaleFactor
            default:
                break
            }
            let sample1 = buildSample(sampleNumber: packetCounter * 2 - 1, rawData: decompressedSamples[1])
            //    this.emit(k.OBCIEmitterSample, sample1);
            let sample2 = buildSample(sampleNumber: packetCounter * 2, rawData: decompressedSamples[2])
            //    this.emit(k.OBCIEmitterSample, sample2);
            
        }
        else {
            var tempCounter = 0
            var slicedData = Data()
            for i in (BoardCommands.obciGanglionPacket19Bit.dataStart.rawValue)...(BoardCommands.obciGanglionPacket19Bit.dataStop.rawValue){
                slicedData[tempCounter] = data[i]
                tempCounter += 1
            }
            decompressSamples(decompressDeltas19Bit(slicedData))
            
            let sample1 = buildSample(sampleNumber: (packetCounter - 100) * 2 - 1, rawData: decompressedSamples[1])
            //    this.emit(k.OBCIEmitterSample, sample1);
            let sample2 = buildSample(sampleNumber: (packetCounter - 100) * 2, rawData: decompressedSamples[2])
            //    this.emit(k.OBCIEmitterSample, sample2);
        }
        
        //Rotate the 0 position for next time
        for i in 0..<k.obciNumberOfChannelsGanglion {
            decompressedSamples[0][i] = decompressedSamples[2][i]
        }
    }
    
    
    /**
     * Route incoming data to proper functions
     * @param data {Buffer} - Data buffer from noble Ganglion.
     * @private
     */
    mutating func processBytes(data: Data){
        if (options.debug) {
            openBCIUtils.debugBytes(prefix: "<<<", data: data)
        }
        lastPacket = data
        let byteId = Int(data[0])
        if (byteId <= BoardCommands.obciGanglionByteId19Bit.max.rawValue){
            processSampleData(data: data)
        }
        else{
            switch byteId {
            case k.obciGanglionByteIdMultiPacket:
                processMultiBytePacket(data: data)
            case k.obciGanglionByteIdMultiPacketStop:
                processMultiBytePacketStop(data: data)
            case k.obciGanglionByteIdImpedanceChannel1,k.obciGanglionByteIdImpedanceChannel2,k.obciGanglionByteIdImpedanceChannel3,k.obciGanglionByteIdImpedanceChannel4,k.obciGanglionByteIdImpedanceChannelReference:
                processImpedanceData(data)
            default:
                processOtherData(data: data)
            }
        }
    }
    
    
    /**
     * Utilize `receivedDeltas` to get actual count values.
     * @param receivedDeltas {Array} - An array of deltas
     *  of shape 2x4 (2 samples per packet and 4 channels per sample.)
     * @private
     */
    mutating func decompressSamples(receivedDeltas: [[Int]]){
        for i in 1..<3{
            for j in 0..<4 {
                decompressedSamples[i][j] = decompressedSamples[i - 1][j] - receivedDeltas[i - 1][j]
            }
        }
    }
    
    /**
     * Builds a sample object from an array and sample number.
     * @param sampleNumber
     * @param rawData
     * @return {{sampleNumber: *}}
     * @private
     */
    func buildSample(sampleNumber: Int, rawData: [Int]) -> Sample {
        var sample = Sample(sampleNummber: sampleNumber, timeStamp: Date().timeIntervalSince1970, channelData: nil)
        if options.sendCounts {
            sample.channelData = rawData
        }
        else {
            sample.channelData = []
            for j in 0..<k.obciNumberOfChannelsGanglion {
                sample.channelData?.append(Int(Double(rawData[j]) * k.obciGanglionScaleFactorPerCountVolts))
            }
        }
        return sample
    }
    
    /**
     * @description Used to send data to the board.
     * @param data {Array | Buffer | Number | String} - The data to write out
     * @returns {Promise} - fulfilled if command was able to be sent
     * @author AJ Keller (@pushtheworldllc)
     */
    func writeToBoard(command: String){
        //Write this value to the BLE characteristic
        //update notify characteristic etc
        
        let dataToSend = command.data(using: String.Encoding.utf8)
        //if (motherView.mainPeripheral != nil) {
        //if (dataToSend != nil) {
        //      motherView.mainPeripheral?.writeValue(dataToSend!, for: motherView.mainCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
        //      }
        //  }
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
}
