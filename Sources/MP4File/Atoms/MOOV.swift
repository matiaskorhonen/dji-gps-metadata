import Foundation

extension Atom {
  class MOOV: Atom {
    override var debugDescription: String {
      "Atom(type=\(type), children=\(children.count))"
    }

    override init(
      data: Data
    ) {
      super.init(data: data)
      self.children = MP4File.parse(data[(data.startIndex + 8)..<data.endIndex])
    }
  }
}
