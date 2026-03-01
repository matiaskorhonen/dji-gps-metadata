import AVFoundation
import ArgumentParser
import Bamf
import Foundation

@main
struct DJIMetadataFixer: AsyncParsableCommand {
  static let allowedTypes = [
    AVFileType.mp4.rawValue,
    AVFileType.mov.rawValue,
    AVFileType.m4v.rawValue,
  ]
  static let issueURL = "https://github.com/matiaskorhonen/dji-gps-metadata/issues/new"

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
  struct SharedOptions: ParsableArguments {
    @Argument(help: "source MP4 file(s)", transform: URL.init(fileURLWithPath:))
    var source: [URL] = []

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
  struct Fix: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Fixes the GPS metadata in DJI MP4 files",
      discussion: """
          If the make and model are not provided, the app will attempt to extract
          them from the video metadata and map the device to a known model.
        """
    )

    @Option(name: [.long, .customShort("m")], help: "Device make (e.g. 'DJI')")
    var make: String?

    @Option(name: [.long, .customShort("d")], help: "Device model (e.g. 'Mini 3 Pro')")
    var model: String?

    @Option(
      name: [.long, .customShort("o")], help: "Output folder",
      transform: { value in
        URL(fileURLWithPath: value)
      })
    var destination: URL? = nil

    @Flag(name: [.long, .short], help: "Overwrite existing files without prompting")
    var force = false

    @OptionGroup var options: DJIMetadataFixer.SharedOptions

    mutating func validate() throws {
      if let destination = destination {
        var isDirectory = ObjCBool(true)
        FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory)

        if !isDirectory.boolValue {
          throw ValidationError("Destination (\(destination.path)) isn't a directory")
        }
      }
    }

    mutating func run() async throws {
      let outputDirectoryPath = destination?.path ?? FileManager.default.currentDirectoryPath

      for url in options.source {
        let basename = NSString(string: url.lastPathComponent).deletingPathExtension
        let filename = "\(basename)-fixed.mov"
        let outputURL = URL(fileURLWithPath: outputDirectoryPath)
          .appendingPathComponent(filename)

        let temporaryDirectoryURL = try FileManager.default.url(
          for: .itemReplacementDirectory,
          in: .userDomainMask,
          appropriateFor: url,
          create: true
        )
        let uuid = UUID().uuidString
        let tempItemURL =
          temporaryDirectoryURL
          .appendingPathComponent(uuid)
          .appendingPathExtension(for: .quickTimeMovie)

        print("Temp item: \(tempItemURL.path)")

        let converter = Converter()
        try await converter.convert(
          input: url,
          output: tempItemURL
        )

        let asset = AVAsset(url: url)
        let mutableAsset = AVMutableMovie(url: tempItemURL)

        let metadata = try await Extractor.extractItems(
          from: asset,
          make: make,
          model: model
        )

        var overwrite = force
        if !overwrite && FileManager.default.fileExists(atPath: outputURL.path) {
          overwrite = prompt("\(outputURL.path) exists. Overwrite?")

          if !overwrite {
            // TODO: Implement a better error
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

        // Clean up the temporary directory
        do {
          try FileManager.default.removeItem(at: temporaryDirectoryURL)
        } catch {
          print("Failed to remove temporary directory: \(error)")
        }
      }
    }
  }
}

extension DJIMetadataFixer {
  struct ListDevices: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "List known devices and models"
    )

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
  struct ParseMetadata: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "metadata",
      abstract: "Parse the metadata from a video file",
      discussion: """
          This command will parse the metadata from a video file and print it to the console.
        """
    )

    @OptionGroup var options: DJIMetadataFixer.SharedOptions

    mutating func run() async throws {
      for url in options.source {
        let bamf = try Bamf(url)
        for atom in bamf.children {
          printAtom(atom)
        }
      }
    }

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
  func prompt(_ message: String) -> Bool {
    let yes = ["y", "yes"]

    print("\(message) [y/N]: ", terminator: "")
    if let response = readLine() {
      return yes.contains(response.lowercased())
    }

    return false
  }
}
