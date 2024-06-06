import Foundation

extension Atom {
  class UDTA: Atom {
    // https://developer.apple.com/documentation/quicktime-file-format/user_data_atom
    // https://developer.apple.com/documentation/quicktime-file-format/user_data_atoms
    var userData: [Atom] {
      return MP4File.parse(data[data.startIndex + 8..<data.endIndex])
    }

    override var debugDescription: String {
      "Atom(type=\(type), children=\(children.count), userData=\(userData))"
    }
  }
}
