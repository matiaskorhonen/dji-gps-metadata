import CoreLocation
import Foundation

/// Parses and normalizes ISO 6709 geographic location strings.
public struct ISO6709 {
  /// Errors thrown while parsing ISO 6709 coordinate strings.
  public enum Error: Swift.Error, Equatable {
    /// The input does not match supported ISO 6709 coordinate formats.
    case invalidFormat(String)
    /// Latitude is outside the valid range of `-90...90`.
    case invalidLatitude(Double)
    /// Longitude is outside the valid range of `-180...180`.
    case invalidLongitude(Double)
  }

  /// Parsed Core Location value.
  public let location: CLLocation

  /// Creates an ISO 6709 representation by parsing a coordinate string.
  ///
  /// - Parameter value: Coordinate string such as `+60.1234+024.5678/`.
  /// - Throws: ``ISO6709/Error`` when parsing fails or values are invalid.
  public init(_ value: String) throws {
    self.location = try Self.parseLocation(from: value)
  }

  /// Creates an ISO 6709 representation from an existing location.
  ///
  /// - Parameter location: Source location.
  public init(location: CLLocation) {
    self.location = location
  }

  /// Returns a normalized ISO 6709 string for the stored location.
  public var normalizedString: String {
    Self.normalizedString(from: location)
  }

  /// Builds a normalized ISO 6709 string from a location.
  ///
  /// - Parameter location: Source location.
  /// - Returns: Normalized ISO 6709 string with trailing `/`.
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
