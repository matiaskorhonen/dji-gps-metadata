import Foundation

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
    print("Type bytes: \(typeBytes.hex)")

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
