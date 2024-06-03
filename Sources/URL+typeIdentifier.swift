import Foundation

extension URL {
  var typeIdentifier: String? {
    (try? resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier
  }
}
