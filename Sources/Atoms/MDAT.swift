import Foundation

extension Atom {
  class MDAT: Atom {
    override init(
      type: AtomType, data: Data
    ) {
      super.init(type: type, data: data)
      self.binary = true
      self.unknown = true
    }
  }
}
