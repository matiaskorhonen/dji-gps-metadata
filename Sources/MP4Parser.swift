import Foundation

// References:
// * https://github.com/corkami/formats/blob/master/container/mp4.md
// * https://www.cimarronsystems.com/wp-content/uploads/2017/04/Elements-of-the-H.264-VideoAAC-Audio-MP4-Movie-v2_0.pdf

enum AtomType: String {
  // case root

  // File Type, Free, and Media Data Atoms
  case ftyp
  case free
  case wide
  case skip
  case mdat

  // Movie and Movie Header Atoms
  case moov
  case mvhd

  // Track and Track Header Atoms
  case trak
  case tkhd

  // Movie Media, Movie Media Header, and Media Handler Reference Atoms
  case mdia
  case mdhd
  case hdlr

  // Media Information, Media Information Header, Media Data Information,
  // and Media Data Reference Atoms
  case minf
  case vmhd
  case dinf
  case dref

  // Sample Table and Sample Description Atoms
  case stbl
  case stsd

  // Sample-to-Time Table and Sync Sample Atoms
  case stts
  case stss

  // Sample-to-Chunk and Sample Sizes Atoms
  case stsc
  case stsz

  // Chunk Offset Atom
  case stco

  // User Data Atom
  case udta

  // Unrecognized atom type
  case unknown
}

class Atom: CustomDebugStringConvertible {
  let size: UInt32
  let type: AtomType
  let data: Data
  var binary: Bool = false
  var unknown: Bool = false

  var children: [Atom] = []

  var debugDescription: String {
    "Atom(size=\(size), type=\(type), children=\(children.count))"
  }

  init(size: UInt32, type: AtomType, data: Data) {
    self.size = size
    self.type = type
    self.data = data
  }

  static func from(size: UInt32, data: Data) -> Atom {
    print("Atom size: \(size)")

    let typeBytes = data.subdata(in: (data.startIndex)..<(data.startIndex + 4))
    print("Type bytes: \(typeBytes.hex())")

    let type = String(data: typeBytes, encoding: .utf8) ?? "unknown"
    print("Type str: \(type)")

    let atomType = AtomType(rawValue: type) ?? .unknown
    print("Atom type: \(atomType)")

    switch atomType {
    case .ftyp:
      return FTYP(size: size, type: atomType, data: data)
    case .mdat:
      return MDAT(size: size, type: atomType, data: data)
    case .wide, .free, .skip:
      return SKIP(size: size, type: atomType, data: data)
    case .mdhd:
      return MDHD(size: size, type: atomType, data: data)
    case .mvhd:
      return MVHD(size: size, type: atomType, data: data)
    case .moov:
      return MOOV(size: size, type: atomType, data: data)
    case .trak:
      return TRAK(size: size, type: atomType, data: data)
    case .tkhd:
      return TKHD(size: size, type: atomType, data: data)
    case .mdia:
      return MDIA(size: size, type: atomType, data: data)
    case .hdlr:
      return HDLR(size: size, type: atomType, data: data)
    case .minf:
      return MINF(size: size, type: atomType, data: data)
    case .vmhd:
      return VMHD(size: size, type: atomType, data: data)
    case .dinf:
      return DINF(size: size, type: atomType, data: data)
    case .dref:
      return DREF(size: size, type: atomType, data: data)
    case .stbl:
      return STBL(size: size, type: atomType, data: data)
    case .stsd:
      return STSD(size: size, type: atomType, data: data)
    case .stts:
      return STTS(size: size, type: atomType, data: data)
    case .stss:
      return STSS(size: size, type: atomType, data: data)
    case .stsc:
      return STSC(size: size, type: atomType, data: data)
    case .stsz:
      return STSZ(size: size, type: atomType, data: data)
    case .stco:
      return STCO(size: size, type: atomType, data: data)
    case .udta:
      return UDTA(size: size, type: atomType, data: data)
    case .unknown:
      return Unknown(size: size, type: atomType, data: data)
    }
  }

}

extension Atom {
  class TRAK: Atom {}
  class TKHD: Atom {}
  class MDIA: Atom {}
  class MDHD: Atom {}
  class HDLR: Atom {}
  class MINF: Atom {}
  class VMHD: Atom {}
  class DINF: Atom {}
  class DREF: Atom {}
  class STBL: Atom {}
  class STSD: Atom {}
  class STTS: Atom {}
  class STSS: Atom {}
  class STSC: Atom {}
  class STSZ: Atom {}
  class STCO: Atom {}
  class UDTA: Atom {}
  class Unknown: Atom {}
}

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

      let atom = Atom.from(size: size, data: atomData)
      print(atom)

      cursor += Int(size)
    }

    // if let stream = InputStream(fileAtPath: url.path) {
    //   var buf = [UInt8](repeating: 0, count: 1024)

    //   stream.open()

    //   stream.read(&buf, maxLength: 1024)

    //   let sizeBytes: Array<UInt8>.SubSequence = buf[..<4]
    //   // let hex = sizeBytes.reduce("") { $0 + String(format: "%02x ", $1) }
    //   //   .trimmingCharacters(in: .whitespacesAndNewlines)

    //   let size = sizeBytes.reduce(0) { soFar, byte in
    //     return soFar << 8 | UInt32(byte)
    //   }
    //   print("Size: \(sizeBytes.hex())")
    //   print("      \(size)")

    //   let typeBytes = buf[4..<8]
    //   print("Type: \(typeBytes.hex())")
    //   print("      \(String(bytes: typeBytes, encoding: .utf8)!)")

    //   let subTypeBytes = buf[8..<12]
    //   print("Subtype: \(subTypeBytes.hex())")
    //   print("         \(String(bytes: subTypeBytes, encoding: .utf8)!)")

    //   var cursor = 12
    //   while cursor < size + 4 {
    //     let atomBytes = buf[cursor..<(cursor + 4)]
    //     let atom = String(bytes: atomBytes, encoding: .utf8)!
    //     print("Atom: \(atom)")
    //     print("      \(atomBytes.hex())")

    //     cursor += 4

    //     let atomValueBytes = buf[(cursor)..<(cursor + 4)]
    //     print("    value: \(atomValueBytes.hex())")

    //     cursor += 4
    //   }

    //   // let nextAtom = buf[12..<16]
    //   // print("Next atom: \(nextAtom.hex())")
    //   // print("           \(String(bytes: nextAtom, encoding: .utf8)!)")

    //   // while case let amount = stream.read(&buf, maxLength: 40), amount > 0 {
    //   //   let hex = buf[..<amount].reduce("") { $0 + String(format: "%02x ", $1) }
    //   //     .trimmingCharacters(in: .whitespacesAndNewlines)
    //   //   print(hex)
    //   // }
    //   stream.close()
    // }
  }

  static func hex(_ bytes: [UInt8]) -> String {
    bytes.reduce("") { $0 + String(format: "%02x ", $1) }
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

extension ArraySlice where Element == UInt8 {
  func hex() -> String {
    self.reduce("") { $0 + String(format: "%02x ", $1) }
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

extension Data {
  func hex() -> String {
    self.reduce("") { $0 + String(format: "%02x ", $1) }
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
