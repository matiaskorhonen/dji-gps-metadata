import Foundation

struct MP4File {
  let data: Data
  let children: [Atom]

  init(_ url: URL) {
    self.data = try! Data(contentsOf: url, options: .alwaysMapped)
    children = MP4File.parse(self.data)
  }

  static func parse(_ data: Data) -> [Atom] {
    var cursor: Int = data.startIndex
    var atoms: [Atom] = []

    while cursor < data.endIndex {
      let sizeBytes = [UInt8](data[cursor..<(cursor + 4)])

      let size = sizeBytes.reduce(0) { soFar, byte in
        return soFar << 8 | UInt32(byte)
      }

      let atomData = data[cursor..<(cursor + Int(size))]

      let atom = Atom.from(data: atomData)
      atoms.append(atom)

      cursor += Int(size)
    }

    return atoms
  }
}
