import Foundation

protocol AtomParser {

}

struct MP4File {
  let data: Data
  let children: [Atom]

  init(_ url: URL) {
    self.data = try! Data(contentsOf: url, options: .alwaysMapped)
    children = MP4File.parse(self.data)
  }

  static func parse(_ data: Data) -> [Atom] {
    var cursor = 0
    var atoms: [Atom] = []

    while cursor < data.endIndex {
      print("Cursor: \(cursor)/\(data.count)")

      let sizeBytes = [UInt8](data[data.startIndex + cursor..<(cursor + 4)])

      let size = sizeBytes.reduce(0) { soFar, byte in
        return soFar << 8 | UInt32(byte)
      }

      let atomData = data[cursor + 4..<(cursor + Int(size))]

      let atom = Atom.from(data: atomData)
      atoms.append(atom)

      cursor += Int(size)
    }

    return atoms
  }
}
