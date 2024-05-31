import AVFoundation
import Foundation
import Photos

public class Exporter {
  var writer: AVAssetWriter!
  var videoInput: AVAssetWriterInput?
  var audioInput: AVAssetWriterInput?

  var reader: AVAssetReader!
  var videoOutput: AVAssetReaderTrackOutput?
  var audioOutput: AVAssetReaderAudioMixOutput?

  var audioCompleted: Bool = false
  var videoCompleted: Bool = false

  let requestQueue = DispatchQueue(
    label: "DJIMetadataFixer.Exporter.RequestQueue", qos: .background)
  let finishQueue = DispatchQueue(
    label: "DJIMetadataFixer.Exporter.FinishQueue", qos: .background)

  // MARK: - Initialization

  public init() {
  }

  // MARK: - Export

  public func export(
    avAsset: AVAsset, toFileType outputFileType: AVFileType = .mp4, atURL outputURL: URL,
    completion: @escaping (URL?) -> Void
  ) {
    guard
      let writer = try? AVAssetWriter(outputURL: outputURL as URL, fileType: outputFileType),
      let reader = try? AVAssetReader(asset: avAsset)
    else {
      completion(nil)
      return
    }

    // Config
    writer.shouldOptimizeForNetworkUse = true

    self.writer = writer
    self.reader = reader

    wire(avAsset)

    // Start
    guard writer.startWriting() else {
      print("Writer failed to start writing.")
      completion(nil)
      return
    }
    guard reader.startReading() else {
      print("Reader failed to start reading.")
      completion(nil)
      return
    }
    writer.startSession(atSourceTime: CMTime.zero)

    // Video
    if let videoOutput = videoOutput,
      let videoInput = videoInput
    {
      print("Writer : \(writer.status) \(String(describing: writer.error))")
      print("Reader : \(reader.status) \(String(describing: reader.error))")

      videoInput.requestMediaDataWhenReady(on: requestQueue) {
        if !self.stream(from: videoOutput, to: videoInput) {
          self.finishQueue.async {
            self.videoCompleted = true
            if self.audioCompleted {
              self.finish(outputURL: outputURL, completion: completion)
            }
          }
        }
      }
    }

    // Audio
    if let audioOutput = audioOutput, let audioInput = audioInput {
      audioInput.requestMediaDataWhenReady(on: requestQueue) {
        if !self.stream(from: audioOutput, to: audioInput) {
          self.finishQueue.async {
            self.audioCompleted = true
            if self.videoCompleted {
              self.finish(outputURL: outputURL, completion: completion)
            }
          }
        }
      }
    }
  }

  // MARK: - Finish

  fileprivate func finish(outputURL: URL, completion: @escaping (URL?) -> Void) {
    print("Finishing...")

    if reader.status == .failed {
      print("Reader status: failed")
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

  // MARK: - Helper

  fileprivate func wire(_ avAsset: AVAsset) {
    wireVideo(avAsset)
    wireAudio(avAsset)
  }

  fileprivate func wireVideo(_ avAsset: AVAsset) {
    let videoTracks = avAsset.tracks(withMediaType: AVMediaType.video)

    if let videoTrack = videoTracks.first {
      // Output
      let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)

      if reader.canAdd(trackOutput) {
        print("Adding track output")
        reader.add(trackOutput)
      } else {
        print("Can't add track output")
      }

      let descriptions = videoTrack.formatDescriptions as! [CMFormatDescription]
      print("\(descriptions)")

      // Input
      let videoInput = AVAssetWriterInput(
        mediaType: AVMediaType.video,
        outputSettings: nil,
        sourceFormatHint: descriptions.first!)
      if writer.canAdd(videoInput) {
        print("Adding video input")
        writer.add(videoInput)
      }

      self.videoInput = videoInput
      self.videoOutput = trackOutput
    } else {
      print("No video tracks found.")
    }
  }

  fileprivate func wireAudio(_ avAsset: AVAsset) {
    let audioTracks = avAsset.tracks(withMediaType: AVMediaType.audio)
    if !audioTracks.isEmpty {
      // Output
      let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
      audioOutput.alwaysCopiesSampleData = true
      if reader.canAdd(audioOutput) {
        reader.add(audioOutput)
      }

      // Input
      let audioInput = AVAssetWriterInput(
        mediaType: AVMediaType.audio,
        outputSettings: nil)
      if writer.canAdd(audioInput) {
        writer.add(audioInput)
      }

      self.audioOutput = audioOutput
      self.audioInput = audioInput
    } else {
      print("No audio tracks found.")
      self.audioCompleted = true
    }
  }

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
