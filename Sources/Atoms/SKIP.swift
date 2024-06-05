import Foundation

extension Atom {
  class SKIP: Atom {
    override init(
      data: Data
    ) {
      super.init(data: data)
      self.binary = true
      self.unknown = true
    }
  }
}
