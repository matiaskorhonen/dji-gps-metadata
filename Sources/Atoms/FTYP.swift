import Foundation

extension Atom {
  class FTYP: Atom {
    var majorBrand: String? {
      let bytes = data[(data.startIndex + 8)..<(data.startIndex + 12)]
      return String(data: bytes, encoding: .utf8)
    }
    var minorVersion: String {
      let bytes = [UInt8](data[(data.startIndex + 12)..<(data.startIndex + 16)])
      let century = String(bytes[0], radix: 16, uppercase: true)
      let year = String(bytes[1], radix: 16, uppercase: true)
      let month = String(bytes[2], radix: 16, uppercase: true)
      let zero = String(bytes[3], radix: 16, uppercase: true)

      return [century + year, month, zero].joined(separator: ".")
    }
    var compatibleBrands: [String] {
      var cursor = data.startIndex + 16
      var brands: [String?] = []
      while cursor < data.endIndex {
        let bytes = data[cursor..<(cursor + 4)]
        guard !bytes.allSatisfy({ UInt8($0) == 0 }) else {
          break
        }
        brands.append(String(data: bytes, encoding: .utf8))
        cursor += 4
      }
      return brands.compactMap { $0 }
    }
    override var debugDescription: String {
      return """
        Atom(
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
