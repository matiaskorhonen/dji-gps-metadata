import AVFoundation
import Foundation

struct MetadataFixPipeline {
  private let converter: VideoConverting
  private let metadataExtractor: MetadataItemExtracting

  init(
    converter: VideoConverting = Converter(),
    metadataExtractor: MetadataItemExtracting = DefaultMetadataItemExtractor()
  ) {
    self.converter = converter
    self.metadataExtractor = metadataExtractor
  }

  func outputURL(for source: URL, destination: URL?) -> URL {
    let outputDirectoryPath = destination?.path ?? FileManager.default.currentDirectoryPath
    let basename = NSString(string: source.lastPathComponent).deletingPathExtension
    let filename = "\(basename)-fixed.mov"
    return URL(fileURLWithPath: outputDirectoryPath).appendingPathComponent(filename)
  }

  func createTemporaryMovieURL(for source: URL) throws -> (directory: URL, item: URL) {
    let temporaryDirectoryURL = try FileManager.default.url(
      for: .itemReplacementDirectory,
      in: .userDomainMask,
      appropriateFor: source,
      create: true
    )

    let temporaryItemURL =
      temporaryDirectoryURL
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(for: .quickTimeMovie)

    return (temporaryDirectoryURL, temporaryItemURL)
  }

  func convertToTemporaryMovie(source: URL, temporaryItemURL: URL) async throws {
    try await converter.convert(input: source, output: temporaryItemURL)
  }

  func extractMetadataItems(from source: URL, make: String?, model: String?) async throws
    -> [AVMetadataItem]
  {
    let asset = AVAsset(url: source)
    return try await metadataExtractor.extractItems(from: asset, make: make, model: model)
  }

  func removeTemporaryDirectory(_ temporaryDirectoryURL: URL) {
    do {
      try FileManager.default.removeItem(at: temporaryDirectoryURL)
    } catch {
      print("Failed to remove temporary directory: \(error)")
    }
  }
}
