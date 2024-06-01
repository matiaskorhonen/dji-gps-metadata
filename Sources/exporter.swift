import AVFoundation
import Foundation
import Photos

public class Exporter {
  var writer: AVAssetWriter!
  var reader: AVAssetReader!

  var inputOutputs: [(input: AVAssetWriterInput, output: AVAssetReaderOutput, completed: Bool)] = []

  let requestQueue = DispatchQueue(
    label: "DJIMetadataFixer.Exporter.RequestQueue", qos: .background)
  let finishQueue = DispatchQueue(
    label: "DJIMetadataFixer.Exporter.FinishQueue", qos: .background)

  // MARK: - Initialization

  public init() {
  }

  // MARK: - Export

  public func export(
    avAsset: AVAsset,
    metadata: [AVMetadataItem],
    toFileType outputFileType: AVFileType = .mp4,
    atURL outputURL: URL
  ) async -> URL? {
    guard
      let writer = try? AVAssetWriter(outputURL: outputURL as URL, fileType: outputFileType),
      let reader = try? AVAssetReader(asset: avAsset)
    else {
      return nil
    }

    // Config
    writer.shouldOptimizeForNetworkUse = true

    writer.metadata = metadata

    self.writer = writer
    self.reader = reader

    await wire(avAsset)

    // Start
    guard writer.startWriting() else {
      // TODO: Raise an error
      return nil
    }
    guard reader.startReading() else {
      // TODO: Raise an error
      return nil
    }
    writer.startSession(atSourceTime: CMTime.zero)

    return await withCheckedContinuation { continuation in
      for (index, element) in inputOutputs.enumerated() {
        let input = element.input
        let output = element.output

        input.requestMediaDataWhenReady(on: requestQueue) {
          if !self.stream(from: output, to: input) {
            self.finishQueue.async {
              self.inputOutputs.replaceSubrange(
                index...index, with: [(input: input, output: output, completed: true)])

              if self.completedAllStreams() {
                self.finish(
                  outputURL: outputURL,
                  completion: { url in
                    continuation.resume(returning: url)
                  })
              }
            }
          }
        }
      }
    }
  }

  fileprivate func completedAllStreams() -> Bool {
    return inputOutputs.allSatisfy { $0.completed }
  }

  // MARK: - Finish

  fileprivate func finish(outputURL: URL, completion: @escaping (URL?) -> Void) {
    if reader.status == .failed {
      // TODO: Raise an error
      writer.cancelWriting()
    }

    guard
      reader.status != .cancelled
        && reader.status != .failed
        && writer.status != .cancelled
        && writer.status != .failed
    else {
      completion(nil)
      return
    }

    writer.finishWriting {
      switch self.writer.status {
      case .completed:
        completion(outputURL)
      default:
        completion(nil)
      }
    }
  }

  // MARK: - Wire inputs and outputs

  fileprivate func wire(_ avAsset: AVAsset) async {
    let types = [
      AVMediaType.video, AVMediaType.audio, AVMediaType.metadata, AVMediaType.subtitle,
      AVMediaType.text, AVMediaType.timecode, AVMediaType.closedCaption, AVMediaType.depthData,
      AVMediaType.haptic, AVMediaType.muxed,
    ]

    // TODO: Raise an error if there are no video tracks

    for type in types {
      let tracks: [AVAssetTrack] = avAsset.tracks(withMediaType: type)
      if tracks.isEmpty {
        // print("No tracks found for type: \(type)")
      } else {
        // print("\(tracks.count) track(s) found for type: \(type)")

        for track in tracks {
          wireTrack(track)
        }
      }
    }
  }

  fileprivate func wireTrack(_ avTrack: AVAssetTrack) {
    let trackOutput = AVAssetReaderTrackOutput(track: avTrack, outputSettings: nil)
    let descriptions = avTrack.formatDescriptions as! [CMFormatDescription]

    if reader.canAdd(trackOutput) {
      // print("✅ Adding track output for \(avTrack.mediaType)")
      reader.add(trackOutput)
    } else {
      // TODO: Raise an error
      // print("❌ Can't add track output for \(avTrack.mediaType)")
    }

    let trackInput = AVAssetWriterInput(
      mediaType: avTrack.mediaType,
      outputSettings: nil,
      sourceFormatHint: descriptions.first!)

    if writer.canAdd(trackInput) {
      // print("Adding track input for \(avTrack.mediaType)")
      writer.add(trackInput)
    }

    inputOutputs.append((input: trackInput, output: trackOutput, completed: false))
  }

  // MARK: - Stream from output to input

  fileprivate func stream(from output: AVAssetReaderOutput, to input: AVAssetWriterInput) -> Bool {
    while input.isReadyForMoreMediaData {
      guard reader.status == .reading && writer.status == .writing,
        let buffer = output.copyNextSampleBuffer()
      else {
        input.markAsFinished()
        return false
      }

      return input.append(buffer)
    }

    return true
  }
}
