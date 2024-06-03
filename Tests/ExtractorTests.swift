import AVFoundation
import DJIMetadataFixer
import Testing

@Suite struct ExtractorTests {
  @Test func extractAtoms0007() async throws {
    let assetURL = resourceURL("DJI_0007.MP4")

    let avAsset = AVAsset(url: assetURL)

    let metadata = try await Extractor.extractMetadata(from: avAsset)

    #expect(metadata["uiso/©xyz"] == "+60.1813+25.0086", "Location should match")
    #expect(metadata["uiso/©xsp"] == "-4.30", "Speed X should match")
    #expect(metadata["uiso/©ysp"] == "-2.50", "Speed Y should match")
    #expect(metadata["uiso/©zsp"] == "+0.00", "Speed Z should match")
    #expect(metadata["uiso/©fpt"] == "-7.10", "Pitch should match")
    #expect(metadata["uiso/©fyw"] == "-148.80", "Yaw should match")
    #expect(metadata["uiso/©frl"] == "-0.10", "Roll should match")
    #expect(metadata["uiso/©gpt"] == "+0.00", "Camera Pitch should match")
    #expect(metadata["uiso/©gyw"] == "+1.00", "Camera Yaw should match")
    #expect(metadata["uiso/©grl"] == "+0.00", "Camera Roll should match")
    #expect(metadata["uiso/©mdl"] == "FC7303", "Device model number should match")
    #expect(metadata["uiso/©csn"] == "1SFOJ8J0AB0GAM", "Serial number should match")
  }

  @Test func extractAtoms0010() async throws {
    let assetURL = resourceURL("DJI_0010.MP4")

    let avAsset = AVAsset(url: assetURL)

    let metadata = try await Extractor.extractMetadata(from: avAsset)

    #expect(metadata["uiso/©xyz"] == "+60.1763+25.0031", "Location should match")
    #expect(metadata["uiso/©xsp"] == "+6.20", "Speed X should match")
    #expect(metadata["uiso/©ysp"] == "+2.70", "Speed Y should match")
    #expect(metadata["uiso/©zsp"] == "-0.90", "Speed Z should match")
    #expect(metadata["uiso/©fpt"] == "+17.20", "Pitch should match")
    #expect(metadata["uiso/©fyw"] == "-154.90", "Yaw should match")
    #expect(metadata["uiso/©frl"] == "-8.00", "Roll should match")
    #expect(metadata["uiso/©gpt"] == "+0.00", "Camera Pitch should match")
    #expect(metadata["uiso/©gyw"] == "+1.80", "Camera Yaw should match")
    #expect(metadata["uiso/©grl"] == "+0.00", "Camera Roll should match")
    #expect(metadata["uiso/©mdl"] == "FC7303", "Device model number should match")
    #expect(metadata["uiso/©csn"] == "1SFOJ8J0AB0GAM", "Serial number should match")
  }

  func resourceURL(_ filename: String) -> URL {
    return URL(fileURLWithPath: #file)
      .deletingLastPathComponent()
      .appendingPathComponent("Resources")
      .appendingPathComponent(filename)
  }
}
