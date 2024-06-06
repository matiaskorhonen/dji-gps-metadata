import Foundation

// References:
// * https://github.com/corkami/formats/blob/master/container/mp4.md
// * https://www.cimarronsystems.com/wp-content/uploads/2017/04/Elements-of-the-H.264-VideoAAC-Audio-MP4-Movie-v2_0.pdf

enum AtomType: CaseIterable {
  static var allCases: [AtomType] {
    return [
      .ftyp,
      .free,
      .wide,
      .skip,
      .mdat,
      .moov,
      .mvhd,
      .trak,
      .tkhd,
      .mdia,
      .mdhd,
      .hdlr,
      .minf,
      .vmhd,
      .dinf,
      .dref,
      .stbl,
      .stsd,
      .stts,
      .stss,
      .stsc,
      .stsz,
      .stco,
      .udta,
    ]
  }

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
  case userDataItem(String)
  case unknown(String)
}
