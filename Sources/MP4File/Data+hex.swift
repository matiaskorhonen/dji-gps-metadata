import Foundation

extension Data {
  var hex: String {
    self.map { String(format: "%02x", $0) }.joined(separator: " ")
  }
}
