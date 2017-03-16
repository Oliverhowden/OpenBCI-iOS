//
//  BoardCommands.swift
//  Flow
//
//  Created by Oliver Howden on 15/3/17.
//  Copyright © 2017 Oliver Howden. All rights reserved.
//
//Contains all the commands to control the OBCI board

struct BoardCommands {
    enum obciGanglionPacket18Bit: Int {
        case auxByte = 20
        case byteId = 0
        case dataStart = 1
        case dataStop = 19
    }
    enum obciGanglionPacket19Bit: Int {
        case byteId = 0
        case dataStart = 1
        case dataStop = 20
    }
    enum obciGanglionByteId18Bit: Int {
        case max = 100
        case min = 1
    }
    enum obciGanglionByteId19Bit: Int {
        case max = 200
        case min = 101
    }
    
    /** Turning channels off */
    public let obciChannelOff1 = "1"
    let obciChannelOff2 = "2"
    let obciChannelOff3 = "3"
    let obciChannelOff4 = "4"
    
    /** Turn channels on */
    let obciChannelOn1 = "!"
    let obciChannelOn2 = "@"
    let obciChannelOn3 = "#"
    let obciChannelOn4 = "$"
    
    /** SD card Commands */
    let obciSDLogForHour1 = "G"
    let obciSDLogForHour2 = "H"
    let obciSDLogForHour4 = "J"
    let obciSDLogForHour12 = "K"
    let obciSDLogForHour24 = "L"
    let obciSDLogForMin5 = "A"
    let obciSDLogForMin15 = "S"
    let obciSDLogForMin30 = "F"
    let obciSDLogForSec14 = "a"
    let obciSDLogStop = "j"
    
    /** SD Card String Commands */
    let obciStringSDHour1 = "1hour"
    let obciStringSDHour2 = "2hour"
    let obciStringSDHour4 = "4hour"
    let obciStringSDHour12 = "12hour"
    let obciStringSDHour24 = "24hour"
    let obciStringSDMin5 = "5min"
    let obciStringSDMin15 = "15min"
    let obciStringSDMin30 = "30min"
    let obciStringSDSec14 = "14sec"
    
    /** Stream Data Commands */
    let obciStreamStart = "b"
    let obciStreamStop = "s"
    
    /** Miscellaneous */
    let obciMiscQueryRegisterSettings = "?"
    let obciMiscSoftReset = "v"
    let obciMiscResend = "o"
    
    /** Possible number of channels */
    let obciNumberOfChannelsGanglion = 4
    
    /** Possible OpenBCI board types */
    let obciBoardGanglion = "ganglion"
    
    /** Possible Simulator Line Noise injections */
    let obciSimulatorLineNoiseHz60 = "60Hz"
    let obciSimulatorLineNoiseHz50 = "50Hz"
    let obciSimulatorLineNoiseNone = "none"
    
    /** Possible Simulator Fragmentation modes */
    let obciSimulatorFragmentationRandom = "random"
    let obciSimulatorFragmentationFullBuffers = "fullBuffers"
    let obciSimulatorFragmentationOneByOne = "oneByOne"
    let obciSimulatorFragmentationNone = "none"
    
    /** Possible Sample Rates */
    let obciSampleRate200 = 200
    
    /** Accel enable/disable commands */
    let obciAccelStart = "n"
    let obciAccelStop = "N"
    
    /** Errors */
    let errorNobleAlreadyScanning = "Scan already under way"
    let errorNobleNotAlreadyScanning = "No scan started"
    let errorNobleNotInPoweredOnState = "Please turn blue tooth on."
    let errorInvalidByteLength = "Invalid Packet Byte Length"
    let errorInvalidByteStart = "Invalid Start Byte"
    let errorInvalidByteStop = "Invalid Stop Byte"
    let errorInvalidType = "Invalid Type"
    // let errorTimeSyncIsNull = ""this.sync.curSyncObj" must not be null"
    let errorTimeSyncNoComma = "Missed the time sync sent confirmation. Try sync again"
    let errorUndefinedOrNullInput = "Undefined or Null Input"
    
    /** Max Master Buffer Size */
    let obciMasterBufferSize = 4096
    
    /** Impedance */
    let obciImpedanceTextBad = "bad"
    let obciImpedanceTextNone = "none"
    let obciImpedanceTextGood = "good"
    let obciImpedanceTextInit = "init"
    let obciImpedanceTextOk = "ok"
    
    let obciImpedanceThresholdGoodMin = 0
    let obciImpedanceThresholdGoodMax = 5000
    let obciImpedanceThresholdOkMin = 5001
    let obciImpedanceThresholdOkMax = 10000
    let obciImpedanceThresholdBadMin = 10001
    let obciImpedanceThresholdBadMax = 1000000
    
    let obciImpedanceSeriesResistor = 2200 // There is a 2.2 k Ohm series resistor that must be subtracted
    
    /** Simulator */
    let obciSimulatorPortName = "OpenBCISimulator"
    
    /** Parse */
    let obciParseFailure = "Failure"
    let obciParseSuccess = "Success"
    
    /** Simulator Board Configurations */
    let obciSimulatorRawAux = "rawAux"
    let obciSimulatorStandard = "standard"
    
    /** Emitters */
    let obciEmitterAccelerometer = "accelerometer"
    let obciEmitterBlePoweredUp = "blePoweredOn"
    let obciEmitterClose = "close"
    let obciEmitterDroppedPacket = "droppedPacket"
    let obciEmitterError = "error"
    let obciEmitterGanglionFound = "ganglionFound"
    let obciEmitterImpedance = "impedance"
    let obciEmitterMessage = "message"
    let obciEmitterQuery = "query"
    let obciEmitterRawDataPacket = "rawDataPacket"
    let obciEmitterReady = "ready"
    let obciEmitterSample = "sample"
    let obciEmitterSynced = "synced"
    
    /** Accel packets */
    let obciGanglionAccelAxisX = 1
    let obciGanglionAccelAxisY = 2
    let obciGanglionAccelAxisZ = 3
    
    /** Accel scale factor */
    let obciGanglionAccelScaleFactor = 0.032 // mG per count
    
    /** Ganglion */
    let obciGanglionBleSearchTime = 20000 // ms
    let obciGanglionByteIdUncompressed = 0
    let obciGanglionByteIdImpedanceChannel1 = 201
    let obciGanglionByteIdImpedanceChannel2 = 202
    let obciGanglionByteIdImpedanceChannel3 = 203
    let obciGanglionByteIdImpedanceChannel4 = 204
    let obciGanglionByteIdImpedanceChannelReference = 205
    let obciGanglionByteIdMultiPacket = 206
    let obciGanglionByteIdMultiPacketStop = 207
    let obciGanglionPacketSize = 20
    let obciGanglionSamplesPerPacket = 2
    let obciGanglionMCP3912Gain = 1.0  // assumed gain setting for MCP3912.  NEEDS TO BE ADJUSTABLE JM
    let obciGanglionMCP3912Vref = 1.2  // reference voltage for ADC in MCP3912 set in hardware
    let obciGanglionPrefix = "Ganglion"
    let obciGanglionSyntheticDataEnable = "t"
    let obciGanglionSyntheticDataDisable = "T"
    let obciGanglionImpedanceStart = "z"
    let obciGanglionImpedanceStop = "Z"
    let obciGanglionScaleFactorPerCountVolts = 1.2 / (8388607.0 * 1.0 * 1.5 * 51.0)
    
    /** Simblee */
    let simbleeUuidService = "fe84"
    let simbleeUuidReceive = "2d30c082f39f4ce6923f3484ea480596"
    let simbleeUuidSend = "2d30c083f39f4ce6923f3484ea480596"
    let simbleeUuidDisconnect = "2d30c084f39f4ce6923f3484ea480596"
    
    /** Noble */
    let obciNobleEmitterPeripheralConnect = "connect"
    let obciNobleEmitterPeripheralDisconnect = "disconnect"
    let obciNobleEmitterPeripheralDiscover = "discover"
    let obciNobleEmitterPeripheralServicesDiscover = "servicesDiscover"
    let obciNobleEmitterServiceCharacteristicsDiscover = "characteristicsDiscover"
    let obciNobleEmitterServiceRead = "read"
    let obciNobleEmitterDiscover = "discover"
    let obciNobleEmitterScanStart = "scanStart"
    let obciNobleEmitterScanStop = "scanStop"
    let obciNobleEmitterStateChange = "stateChange"
    let obciNobleStatePoweredOn = "poweredOn"
}
