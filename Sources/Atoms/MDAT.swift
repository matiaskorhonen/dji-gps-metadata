import Foundation

extension Atom {
  class MDAT: Atom {
    override init(
      size: UInt32, type: AtomType, data: Data
    ) {
      super.init(size: size, type: type, data: data)
      self.binary = true
      self.unknown = true
    }
  }
}
