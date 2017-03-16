
import Foundation


struct OpenBCIUtils{
    /**
     * @description Output passed bytes on the console as a hexdump, if enabled
     * @param prefix - label to show to the left of bytes
     * @param data - bytes to output, a buffer or string
     * @private
     */
    func debugBytes(prefix: String, data: Data) {
        print("Debug Bytes:")
        for j in 0..<data.count{
            var hexPart = ""
            var ascPart = ""
            for _ in j..<min(data.count, j + 16){
                let byt = data[j]
                let hex = "0" + String(format:"%2X", byt)
                //need to slice(-2) here?
                hexPart += (((j & 0xf) == 0x8) ? "  " : " " )
                hexPart += hex
                var str = ""
                str.append(Character(UnicodeScalar(byt)))
                let asc = (byt >= 0x20 && byt < 0x7f) ? str : "."
                ascPart += asc
                hexPart = (hexPart + "                                                   ")
                let indexStartOfHex = hexPart.index(hexPart.startIndex, offsetBy: 0)
                let indexEndOfHex = hexPart.index(hexPart.startIndex, offsetBy: 3*17)
                let rangeOfHex = indexStartOfHex ..< indexEndOfHex
                hexPart = hexPart.substring(with: rangeOfHex)
                print(prefix + " " + hexPart + "|" + ascPart + "|")
            }
        }
    }
}
