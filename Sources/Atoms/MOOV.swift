import Foundation

extension Atom {
  class MOOV: Atom {
    override var debugDescription: String {
      "Atom(size=\(size), type=\(type), children=\(children.count))"
    }
  }
}
