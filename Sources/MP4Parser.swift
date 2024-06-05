import Foundation

struct MP4Parser {
  static func parse(_ url: URL) {
    let data = try! Data(contentsOf: url, options: .alwaysMapped)

    var cursor = 0
    while cursor < data.count {
      print("Cursor: \(cursor)/\(data.count)")

      let sizeBytes = [UInt8](data[cursor..<(cursor + 4)])

      let size = sizeBytes.reduce(0) { soFar, byte in
        return soFar << 8 | UInt32(byte)
      }

      let atomData = data[cursor + 4..<(cursor + Int(size))]

      let atom = Atom.from(data: atomData)
      print(atom)

      cursor += Int(size)
    }
  }
}
