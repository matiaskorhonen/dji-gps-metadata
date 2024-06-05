import Foundation

struct MP4File {
  let data: Data
  var atoms: [Atom] = []

  init(_ url: URL) {
    self.data = try! Data(contentsOf: url, options: .alwaysMapped)
    parse()
  }

  private mutating func parse() {
    var cursor = 0
    while cursor < data.count {
      print("Cursor: \(cursor)/\(data.count)")

      let sizeBytes = [UInt8](data[cursor..<(cursor + 4)])

      let size = sizeBytes.reduce(0) { soFar, byte in
        return soFar << 8 | UInt32(byte)
      }

      let atomData = data[cursor + 4..<(cursor + Int(size))]

      let atom = Atom.from(data: atomData)
      atoms.append(atom)

      cursor += Int(size)
    }
  }
}
