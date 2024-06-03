import AVFoundation
import ArgumentParser
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
    subcommands: [Fix.self, ListDevices.self],
    defaultSubcommand: Fix.self
  )
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

    @Argument(help: "source MP4 file(s)", transform: URL.init(fileURLWithPath:))
    var source: [URL] = []

    mutating func validate() throws {
      if let destination = destination {
        var isDirectory = ObjCBool(true)
        FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory)

        if !isDirectory.boolValue {
          throw ValidationError("Destination (\(destination.path)) isn't a directory")
        }
      }

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

    mutating func run() async throws {
      let outputDirectoryPath = destination?.path ?? FileManager.default.currentDirectoryPath

      for url in source {
        let asset = AVAsset(url: url)

        let metadata = try await Extractor.extractItems(from: asset)

        let basename = NSString(string: url.lastPathComponent).deletingPathExtension
        let filename = "\(basename).mp4"
        let outputURL = URL(fileURLWithPath: outputDirectoryPath)
          .appendingPathComponent(filename)

        var overwrite = force
        if !overwrite && FileManager.default.fileExists(atPath: outputURL.path) {
          overwrite = prompt("\(outputURL.path) exists. Overwrite?")

          if !overwrite {
            // TODO: Implement a better error
            throw ValidationError("File exists: \(outputURL.path)")
          }
        }

        let temporaryDirectoryURL = try FileManager.default.url(
          for: .itemReplacementDirectory,
          in: .userDomainMask,
          appropriateFor: outputURL,
          create: true
        )
        let tempItemURL = temporaryDirectoryURL.appendingPathComponent(filename)

        let exporter = Exporter()

        let exportURL = await exporter.export(
          avAsset: asset,
          metadata: metadata,
          toFileType: .mp4,
          atURL: tempItemURL)

        if exportURL == nil {
          print("Failed to export \(url.path)")
        } else {
          if overwrite {
            // Replace the existing item if it exists
            try FileManager.default.replaceItem(
              at: outputURL, withItemAt: exportURL!, backupItemName: "_\(filename).backup",
              options: .usingNewMetadataOnly,
              resultingItemURL: nil)
          } else {
            // Safely move the item to the output directory, throws an error if the
            // item already exists
            try FileManager.default.moveItem(at: exportURL!, to: outputURL)
          }

          print("Exported \(url.lastPathComponent) to \(outputURL.path)")
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
