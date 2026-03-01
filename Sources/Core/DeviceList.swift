/// Represents a known DJI device make and model pair.
public struct Device: Equatable, Sendable {
  /// Device manufacturer name.
  public let make: String
  /// Device model name.
  public let model: String

  /// Creates a device descriptor.
  ///
  /// - Parameters:
  ///   - make: Device manufacturer.
  ///   - model: Device model name.
  public init(make: String, model: String) {
    self.make = make
    self.model = model
  }
}

/// Provides lookup utilities for known DJI camera model identifiers.
public struct DeviceList {
  /// Known DJI model identifier mappings to human-readable devices.
  public static let devices = [
    "FC1102": Device(make: "DJI", model: "Spark"),
    "FC220": Device(make: "DJI", model: "Mavic Pro"),
    "FC300C": Device(make: "DJI", model: "Phantom 3"),
    "FC300S": Device(make: "DJI", model: "Phantom 3 Pro"),
    "FC300SE": Device(make: "DJI", model: "Phantom 3 Pro"),
    "FC300X": Device(make: "DJI", model: "Phantom 3 Pro"),
    "FC300XW": Device(make: "DJI", model: "Phantom 3 Adv"),
    "FC3170": Device(make: "DJI", model: "Mavic Air 2"),
    "FC330": Device(make: "DJI", model: "Phantom 4"),
    "FC3411": Device(make: "DJI", model: "Air 2S"),
    "FC350": Device(make: "DJI", model: "X3"),
    "FC550": Device(make: "DJI", model: "X5"),
    "FC6310": Device(make: "DJI", model: "Phantom 4 Pro"),
    "FC6510": Device(make: "DJI", model: "X4S"),
    "FC6520": Device(make: "DJI", model: "X5S"),
    "FC6540": Device(make: "DJI", model: "X7"),
    "FC7203": Device(make: "DJI", model: "Mavic Mini"),
    "HG310": Device(make: "DJI", model: "OSMO"),
    "OT110": Device(make: "DJI", model: "Osmo Pocket"),
    // Mavic 2 Pro
    "L1D-20": Device(make: "Hasselblad", model: "L1D-20"),
    // Mavic 3
    "L2D-20c": Device(make: "Hasselblad", model: "L2D-20c"),
    "FC7303": Device(make: "DJI", model: "Mini 2"),
    "FC3582": Device(make: "DJI", model: "Mini 3 Pro"),
    "FC8482": Device(make: "DJI", model: "Mini 4 Pro"),
  ]

  /// Looks up a known device by DJI model identifier.
  ///
  /// - Parameter model: DJI model identifier (for example, `FC3582`).
  /// - Returns: The mapped device when available, otherwise `nil`.
  public static func lookup(for model: String) -> Device? {
    return devices[model]
  }
}
