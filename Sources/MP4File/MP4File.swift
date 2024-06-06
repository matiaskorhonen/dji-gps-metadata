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

      var size = sizeBytes.reduce(0) { soFar, byte in
        return soFar << 8 | UInt64(byte)
      }

      // https://github.com/corkami/formats/blob/master/container/mp4.md
      if size == 0 {
        // Size = null → read until the end of the file
        size = UInt64(data.endIndex) - UInt64(cursor + 8)
      } else if size == 1 {
        // Size = 1 → extended size
        let extendedSizeBytes = [UInt8](data[(cursor + 8)..<(cursor + 16)])
        size = extendedSizeBytes.reduce(0) { soFar, byte in
          return soFar << 8 | UInt64(byte)
        }
      }

      let atomData = data[cursor..<(cursor + Int(size))]

      let atom = Atom.from(data: atomData)
      atoms.append(atom)

      cursor += Int(size)
    }

    return atoms
  }
}
