import CoreLocation
import DJIMetadataCore
import Testing

@Suite struct ISO6709Tests {
  @Test func parsesCoordinateWithoutAltitude() throws {
    let iso = try ISO6709("+60.1813+25.0086")

    #expect(abs(iso.location.coordinate.latitude - 60.1813) < 0.000_001)
    #expect(abs(iso.location.coordinate.longitude - 25.0086) < 0.000_001)
    #expect(iso.location.verticalAccuracy < 0)
    #expect(iso.normalizedString == "+60.1813+025.0086/")
  }

  @Test func parsesCoordinateWithAltitude() throws {
    let iso = try ISO6709("+60.1798+024.9818+021.603/")

    #expect(abs(iso.location.coordinate.latitude - 60.1798) < 0.000_001)
    #expect(abs(iso.location.coordinate.longitude - 24.9818) < 0.000_001)
    #expect(abs(iso.location.altitude - 21.603) < 0.000_001)
    #expect(iso.normalizedString == "+60.1798+024.9818+21.603/")
  }

  @Test func normalizesFromCLLocationWithoutAltitude() {
    let location = CLLocation(latitude: 60.1813, longitude: 25.0086)

    #expect(ISO6709.normalizedString(from: location) == "+60.1813+025.0086/")
  }

  @Test func normalizesFromCLLocationWithAltitude() {
    let location = CLLocation(
      coordinate: CLLocationCoordinate2D(latitude: 60.1798, longitude: 24.9818),
      altitude: 21.603,
      horizontalAccuracy: 5,
      verticalAccuracy: 3,
      timestamp: .now
    )

    #expect(ISO6709.normalizedString(from: location) == "+60.1798+024.9818+21.603/")
  }

  @Test func rejectsInvalidFormat() {
    do {
      _ = try ISO6709("60.1813+25.0086")
      Issue.record("Expected parsing to fail")
    } catch let error as ISO6709.Error {
      #expect(error == .invalidFormat("60.1813+25.0086"))
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test func rejectsOutOfRangeCoordinates() {
    do {
      _ = try ISO6709("+91.0+025.0/")
      Issue.record("Expected parsing to fail")
    } catch let error as ISO6709.Error {
      switch error {
      case .invalidLatitude(let latitude):
        #expect(latitude == 91.0)
      default:
        Issue.record("Unexpected ISO6709 error: \(error)")
      }
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }
}
