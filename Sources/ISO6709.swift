import CoreLocation
import Foundation

public struct ISO6709 {
  public enum Error: Swift.Error, Equatable {
    case invalidFormat(String)
    case invalidLatitude(Double)
    case invalidLongitude(Double)
  }

  public let location: CLLocation

  public init(_ value: String) throws {
    self.location = try Self.parseLocation(from: value)
  }

  public init(location: CLLocation) {
    self.location = location
  }

  public var normalizedString: String {
    Self.normalizedString(from: location)
  }

  public static func normalizedString(from location: CLLocation) -> String {
    let latitude = formatComponent(location.coordinate.latitude, minimumIntegerDigits: 2)
    let longitude = formatComponent(location.coordinate.longitude, minimumIntegerDigits: 3)

    if location.verticalAccuracy >= 0 {
      let altitude = formatComponent(location.altitude, minimumIntegerDigits: 2)
      return "\(latitude)\(longitude)\(altitude)/"
    }

    return "\(latitude)\(longitude)/"
  }

  private static func parseLocation(from value: String) throws -> CLLocation {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let raw = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed

    let pattern = #"^([+-]\d+(?:\.\d+)?)([+-]\d+(?:\.\d+)?)([+-]\d+(?:\.\d+)?)?$"#
    let regex = try NSRegularExpression(pattern: pattern)

    let nsRaw = raw as NSString
    let range = NSRange(location: 0, length: nsRaw.length)
    guard
      let match = regex.firstMatch(in: raw, options: [], range: range),
      match.numberOfRanges >= 3
    else {
      throw Error.invalidFormat(value)
    }

    let latitudeString = nsRaw.substring(with: match.range(at: 1))
    let longitudeString = nsRaw.substring(with: match.range(at: 2))
    let altitudeString: String? = {
      let altitudeRange = match.range(at: 3)
      guard altitudeRange.location != NSNotFound else {
        return nil
      }
      return nsRaw.substring(with: altitudeRange)
    }()

    guard let latitude = Double(latitudeString) else {
      throw Error.invalidFormat(value)
    }

    guard let longitude = Double(longitudeString) else {
      throw Error.invalidFormat(value)
    }

    guard (-90.0...90.0).contains(latitude) else {
      throw Error.invalidLatitude(latitude)
    }

    guard (-180.0...180.0).contains(longitude) else {
      throw Error.invalidLongitude(longitude)
    }

    if let altitudeString, let altitude = Double(altitudeString) {
      return CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
        altitude: altitude,
        horizontalAccuracy: 0,
        verticalAccuracy: 0,
        timestamp: .now
      )
    }

    return CLLocation(latitude: latitude, longitude: longitude)
  }

  private static func formatComponent(_ value: Double, minimumIntegerDigits: Int) -> String {
    let sign = value >= 0 ? "+" : "-"
    let absolute = abs(value)

    let formatted = String(format: "%.6f", absolute)
    let parts = formatted.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    let integerPart = String(parts.first ?? "0")
    let paddedIntegerPart =
      integerPart.count < minimumIntegerDigits
      ? String(repeating: "0", count: minimumIntegerDigits - integerPart.count) + integerPart
      : integerPart

    var fractionalPart = String(parts.count > 1 ? parts[1] : "")
    while fractionalPart.hasSuffix("0") {
      fractionalPart.removeLast()
    }

    if fractionalPart.isEmpty {
      return "\(sign)\(paddedIntegerPart)"
    }

    return "\(sign)\(paddedIntegerPart).\(fractionalPart)"
  }
}
