import AVFoundation
import ArgumentParser
import Bamf
import DJIMetadataCore
import Foundation

/// Command-line entry point for fixing DJI video metadata.
@main
struct DJIMetadataFixer: AsyncParsableCommand {
  /// Supported input file type identifiers.
  static let allowedTypes = [
    AVFileType.mp4.rawValue,
    AVFileType.mov.rawValue,
    AVFileType.m4v.rawValue,
  ]
  /// URL for reporting unsupported devices.
  static let issueURL = "https://github.com/matiaskorhonen/dji-gps-metadata/issues/new"

  /// Top-level command configuration.
  static let configuration = CommandConfiguration(
    abstract: "DJI GPS Metadata for Photos.app",
    discussion: """
        If the make and model are not provided, the app will attempt to extract
        them from the video metadata and map the device to a known model.
      """,
    subcommands: [Fix.self, ParseMetadata.self, ListDevices.self],
    defaultSubcommand: Fix.self
  )
}

extension DJIMetadataFixer {
  /// Shared input options used by metadata commands.
  struct SharedOptions: ParsableArguments {
    /// Source video files to process.
    @Argument(help: "source MP4 file(s)", transform: URL.init(fileURLWithPath:))
    var source: [URL] = []

    /// Validates source files and supported media types.
    mutating func validate() throws {
      guard !source.isEmpty else {
        throw ValidationError("Missing expected argument '<source> ...'")
      }

      let missingSources = source.compactMap({ url -> String? in
        guard FileManager.default.isReadableFile(atPath: url.path) else {
          return url.path
        }

        return nil
      })

      guard missingSources.isEmpty else {
        throw ValidationError(
          "Unreadable source \(missingSources.count == 1 ? "file": "files"): \(missingSources.joined(separator: ", "))"
        )
      }

      let wrongTypes = source.compactMap({ url -> String? in
        let typeIdentifier = (try? url.resourceValues(forKeys: [.typeIdentifierKey]))

        guard DJIMetadataFixer.allowedTypes.contains(typeIdentifier?.typeIdentifier ?? "") else {
          return url.path
        }

        return nil
      })

      guard wrongTypes.isEmpty else {
        throw ValidationError(
          "Invalid source \(wrongTypes.count == 1 ? "file": "files") (not MP4 or QuickTime): \(wrongTypes.joined(separator: ", "))"
        )
      }
    }
  }
}

extension DJIMetadataFixer {
  /// Main command that exports a new MOV with corrected metadata.
  struct Fix: AsyncParsableCommand {
    /// Command metadata for `fix`.
    static let configuration = CommandConfiguration(
      abstract: "Fixes the GPS metadata in DJI MP4 files",
      discussion: """
          If the make and model are not provided, the app will attempt to extract
          them from the video metadata and map the device to a known model.
        """
    )

    /// Device make override.
    @Option(name: [.long, .customShort("m")], help: "Device make (e.g. 'DJI')")
    var make: String?

    /// Device model override.
    @Option(name: [.long, .customShort("d")], help: "Device model (e.g. 'Mini 3 Pro')")
    var model: String?

    /// Output directory for processed files.
    @Option(
      name: [.long, .customShort("o")], help: "Output folder",
      transform: { value in
        URL(fileURLWithPath: value)
      })
    var destination: URL? = nil

    /// Overwrites existing output files when set.
    @Flag(name: [.long, .short], help: "Overwrite existing files without prompting")
    var force = false

    /// Shared source options.
    @OptionGroup var options: DJIMetadataFixer.SharedOptions

    /// Validates command options.
    mutating func validate() throws {
      if let destination = destination {
        var isDirectory = ObjCBool(true)
        FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory)

        if !isDirectory.boolValue {
          throw ValidationError("Destination (\(destination.path)) isn't a directory")
        }
      }
    }

    /// Runs metadata extraction and re-export for each source file.
    mutating func run() async throws {
      let pipeline = MetadataFixPipeline()

      for url in options.source {
        let outputURL = pipeline.outputURL(for: url, destination: destination)
        let temporaryResources = try pipeline.createTemporaryMovieURL(for: url)
        let tempItemURL = temporaryResources.item

        print("Temp item: \(tempItemURL.path)")

        try await pipeline.convertToTemporaryMovie(source: url, temporaryItemURL: tempItemURL)

        let mutableAsset = AVMutableMovie(url: tempItemURL)

        let metadata = try await pipeline.extractMetadataItems(
          from: url,
          make: make,
          model: model
        )

        var overwrite = force
        if !overwrite && FileManager.default.fileExists(atPath: outputURL.path) {
          overwrite = prompt("\(outputURL.path) exists. Overwrite?")

          if !overwrite {
            // Keep this as a validation error until a dedicated user-cancelled error is introduced.
            throw ValidationError("File exists: \(outputURL.path)")
          }
        }

        print("Metadata: \(metadata)")

        await AVAssetExportSession.compatibility(
          ofExportPreset: AVAssetExportPresetPassthrough, with: mutableAsset, outputFileType: .mov)

        let exportSession = AVAssetExportSession(
          asset: mutableAsset,
          presetName: AVAssetExportPresetPassthrough
        )!

        exportSession.shouldOptimizeForNetworkUse = true

        if #available(macOS 13.0, *) {
          exportSession.audioTrackGroupHandling = .preserveAlternateTracks
        }

        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.metadata = metadata
        exportSession.outputFileType = .mov
        exportSession.outputURL = outputURL

        if overwrite && FileManager.default.fileExists(atPath: outputURL.path) {
          var resultingURL: NSURL?
          try FileManager.default.trashItem(at: outputURL, resultingItemURL: &resultingURL)
          print("Moved existing file to Trash (\(resultingURL?.path ?? "—"))")
        }

        await exportSession.export()

        guard exportSession.status == .completed else {
          throw ValidationError(
            "Export failed for \(url.lastPathComponent): \(exportSession.error?.localizedDescription ?? "Unknown error")"
          )
        }

        print("Wrote to \(outputURL.path)")
        pipeline.removeTemporaryDirectory(temporaryResources.directory)
      }
    }
  }
}

extension DJIMetadataFixer {
  /// Lists known DJI model identifiers and mapped device names.
  struct ListDevices: ParsableCommand {
    /// Command metadata for `list-devices`.
    static let configuration = CommandConfiguration(
      abstract: "List known devices and models"
    )

    /// Prints known devices and support issue URL.
    mutating func run() {
      print("Known devices:\n")
      for (model, device) in DeviceList.devices {
        print("* \(model): \(device.make) \(device.model)")
      }
      print(
        """

        Do you have a drone that isn't listed here? Please \u{001B}]8;;\(DJIMetadataFixer.issueURL)\u{001B}\\open an issue\u{001B}]8;;\u{001B}\\ on GitHub
        → \(DJIMetadataFixer.issueURL)
        """
      )
    }
  }
}

extension DJIMetadataFixer {
  /// Debug command that prints parsed MP4 atom metadata.
  struct ParseMetadata: AsyncParsableCommand {
    /// Command metadata for `metadata`.
    static let configuration = CommandConfiguration(
      commandName: "metadata",
      abstract: "Parse the metadata from a video file",
      discussion: """
          This command will parse the metadata from a video file and print it to the console.
        """
    )

    /// Shared source options.
    @OptionGroup var options: DJIMetadataFixer.SharedOptions

    /// Prints metadata atoms for each input source file.
    mutating func run() async throws {
      for url in options.source {
        let bamf = try Bamf(url)
        for atom in bamf.children {
          printAtom(atom)
        }
      }
    }

    /// Recursively prints an atom tree with indentation.
    ///
    /// - Parameters:
    ///   - atom: Atom to print.
    ///   - level: Current indentation level.
    private func printAtom(_ atom: Atom, level: Int = 0) {
      let indent = String(repeating: "  ", count: level)
      print("\(indent)\(atom)")

      for child in atom.displayChildren {
        printAtom(child, level: level + 1)
      }
    }
  }
}

extension DJIMetadataFixer.Fix {
  /// Prompts for a yes/no confirmation.
  ///
  /// - Parameter message: Prompt shown to the user.
  /// - Returns: `true` when the user answers yes.
  func prompt(_ message: String) -> Bool {
    let yes = ["y", "yes"]

    print("\(message) [y/N]: ", terminator: "")
    if let response = readLine() {
      return yes.contains(response.lowercased())
    }

    return false
  }
}
