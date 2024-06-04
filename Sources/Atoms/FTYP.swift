import Foundation

extension Atom {
  class FTYP: Atom {
    var majorBrand: String? {
      let bytes = data[(data.startIndex + 4)..<(data.startIndex + 8)]
      return String(data: bytes, encoding: .utf8)
    }
    var minorVersion: Decimal {
      // TODO: convert BCD to Decimal

      // let bytes = [UInt8](data[(data.startIndex + 8)..<(data.startIndex + 12)])

      // let version = bytes.reduce(0) { soFar, byte in
      //   return soFar << 8 | UInt32(byte)
      // }

      return 0
    }
    var compatibleBrands: [String] {
      return []
    }
    override var debugDescription: String {
      return """
        Atom(
          size=\(size),
          type=\(type),
          children=\(children.count)
          majorBrand=\(majorBrand ?? "nil")
          minorVersion=\(minorVersion)
          compatibleBrands=\(compatibleBrands)
        )
        """
    }
  }
}
