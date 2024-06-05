import Foundation

extension Atom {
  class MOOV: Atom {
    override var debugDescription: String {
      "Atom(type=\(type), children=\(children.count))"
    }
  }
}
