import AVFoundation
import DJIMetadataFixer
import Testing

@Suite struct DeviceListTests {
  @Test func lookupUnknownDevice() {
    let device = DeviceList.lookup(for: "Unknown")
    #expect(device == nil, "Device should be nil")
  }

  @Test func lookupDJIDevices() {
    let dji = [
      "FC1102",
      "FC220",
      "FC300C",
      "FC300S",
      "FC300SE",
      "FC300X",
      "FC300XW",
      "FC3170",
      "FC330",
      "FC3411",
      "FC350",
      "FC550",
      "FC6310",
      "FC6510",
      "FC6520",
      "FC6540",
      "FC7203",
      "HG310",
      "OT110",
      "FC7303",
      "FC3582",
      "FC8482",
    ]

    for model in dji {
      let device = DeviceList.lookup(for: model)
      #expect(device?.make == "DJI", "Make should be DJI")
      #expect(device?.model != nil, "Model should not be nil")
    }
  }

  @Test func lookupHasselbladDevices() {
    let hasselblad = [
      "L1D-20",
      "L2D-20c",
    ]

    for model in hasselblad {
      let device = DeviceList.lookup(for: model)
      #expect(device?.make == "Hasselblad", "Make should be Hasselblad")
      #expect(device?.model != nil, "Model should not be nil")
    }
  }
}
