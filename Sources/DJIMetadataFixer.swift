import AVFoundation
import ArgumentParser
import Foundation
import SwiftPrompt

/*
# ARG_OPTIONAL_SINGLE([make],[m],[Device make],[DJI])
# ARG_OPTIONAL_SINGLE([model],[d],[Device model],[Mini 2])
# ARG_OPTIONAL_SINGLE([destination],[o],[Output folder (defaults to same folder as the source file)])
# ARG_OPTIONAL_BOOLEAN([non-video],[i],[Copy or move non-video source files. Only valid when a destination is set])
# ARG_OPTIONAL_BOOLEAN([remove-original],[r],[Remove source file after processing])
# ARG_POSITIONAL_INF([filename],[source MP4 file],[1])
# ARG_HELP([DJI GPS Metadata for Photos.app])
*/

/*
$ ./dji-gps-metadata.sh --help
DJI GPS Metadata for Photos.app
Usage: ./dji-gps-metadata.sh [-m|--make <arg>] [-d|--model <arg>] [-o|--destination <arg>] [-i|--(no-)non-video] [-r|--(no-)remove-original] [-h|--help] <filename-1> [<filename-2>] ... [<filename-n>] ...
	<filename>: source MP4 file
	-m, --make: Device make (default: 'DJI')
	-d, --model: Device model (default: 'Mini 2')
	-o, --destination: Output folder (defaults to same folder as the source file) (no default)
	-i, --non-video, --no-non-video: Copy or move non-video source files. Only valid when a destination is set (off by default)
	-r, --remove-original, --no-remove-original: Remove source file after processing (off by default)
	-h, --help: Prints help
*/

@main
struct DJIMetadataFixer: AsyncParsableCommand {
  static let configuration = CommandConfiguration(abstract: "DJI GPS Metadata for Photos.app")

  @Option(name: [.long, .customShort("m")], help: "Device make")
  var make: String = "DJI"

  @Option(name: [.long, .customShort("d")], help: "Device model")
  var model: String = "Mini 2"

  @Option(
    name: [.long, .customShort("o")], help: "Output folder",
    transform: { value in
      URL(fileURLWithPath: value)
    })
  var destination: URL? = nil

  @Flag(
    name: [.long, .customShort("i")],
    help: "Copy or move non-video source files. Only valid when a destination is set.")
  var nonVideo = false

  @Flag(name: [.long, .customShort("r")], help: "Remove source file after processing.")
  var removeOriginal = false

  @Argument(help: "source MP4 file(s)", transform: URL.init(fileURLWithPath:))
  var source: [URL]

  mutating func run() async throws {
    let outputDirectoryPath = destination?.path ?? FileManager.default.currentDirectoryPath

    var isDirectory = ObjCBool(true)
    FileManager.default.fileExists(atPath: outputDirectoryPath, isDirectory: &isDirectory)

    if !isDirectory.boolValue {
      throw ValidationError("Destination must be a directory")
    }

    for url in source {
      let asset = AVAsset(url: url)

      let metadata = try await Extractor.extractItems(from: asset)

      let filename = url.lastPathComponent
      let outputURL = URL(fileURLWithPath: outputDirectoryPath)
        .appendingPathComponent(filename)

      var overwrite = false
      if FileManager.default.fileExists(atPath: outputURL.path) {
        let options: [PromptOption<Bool>] = [
          .init(title: "Yes", value: true),
          .init(title: "No", value: false),
        ]

        overwrite = Prompt.selectOption(
          question: "\(outputURL.path) exists. Overwrite?",
          options: options
        )

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
        continue
      }

      if overwrite {
        // Replace the existing item if it exists
        try FileManager.default.replaceItem(
          at: outputURL, withItemAt: exportURL!, backupItemName: "\(filename).bak",
          options: .usingNewMetadataOnly,
          resultingItemURL: nil)
      } else {
        // Safely move the item to the output directory, throws an error if the
        // item already exists
        try FileManager.default.moveItem(at: exportURL!, to: outputURL)
      }
    }
  }
}
