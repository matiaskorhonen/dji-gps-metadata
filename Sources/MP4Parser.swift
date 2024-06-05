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
  let type: AtomType
  let data: Data
  var binary: Bool = false
  var unknown: Bool = false

  var children: [Atom] = []

  var debugDescription: String {
    "Atom(type=\(type), children=\(children.count))"
  }

  init(type: AtomType, data: Data) {
    self.type = type
    self.data = data
  }

  static func from(data: Data) -> Atom {
    let typeBytes = data.subdata(in: (data.startIndex)..<(data.startIndex + 4))
    print("Type bytes: \(typeBytes.hex())")

    let type = String(data: typeBytes, encoding: .utf8) ?? "unknown"
    print("Type str: \(type)")

    let atomType = AtomType(rawValue: type) ?? .unknown
    print("Atom type: \(atomType)")

    switch atomType {
    case .ftyp:
      return FTYP(type: atomType, data: data)
    case .mdat:
      return MDAT(type: atomType, data: data)
    case .wide, .free, .skip:
      return SKIP(type: atomType, data: data)
    case .mdhd:
      return MDHD(type: atomType, data: data)
    case .mvhd:
      return MVHD(type: atomType, data: data)
    case .moov:
      return MOOV(type: atomType, data: data)
    case .trak:
      return TRAK(type: atomType, data: data)
    case .tkhd:
      return TKHD(type: atomType, data: data)
    case .mdia:
      return MDIA(type: atomType, data: data)
    case .hdlr:
      return HDLR(type: atomType, data: data)
    case .minf:
      return MINF(type: atomType, data: data)
    case .vmhd:
      return VMHD(type: atomType, data: data)
    case .dinf:
      return DINF(type: atomType, data: data)
    case .dref:
      return DREF(type: atomType, data: data)
    case .stbl:
      return STBL(type: atomType, data: data)
    case .stsd:
      return STSD(type: atomType, data: data)
    case .stts:
      return STTS(type: atomType, data: data)
    case .stss:
      return STSS(type: atomType, data: data)
    case .stsc:
      return STSC(type: atomType, data: data)
    case .stsz:
      return STSZ(type: atomType, data: data)
    case .stco:
      return STCO(type: atomType, data: data)
    case .udta:
      return UDTA(type: atomType, data: data)
    case .unknown:
      return Unknown(type: atomType, data: data)
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

      let atom = Atom.from(data: atomData)
      print(atom)

      cursor += Int(size)
    }
extension Data {
  func hex() -> String {
    self.reduce("") { $0 + String(format: "%02x ", $1) }
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
