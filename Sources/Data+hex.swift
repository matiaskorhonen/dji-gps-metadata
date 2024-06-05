import Foundation

extension Data {
  func hex() -> String {
    self.map { String(format: "%02x ", $0) }.joined(separator: " ")
  }
}
