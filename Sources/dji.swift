import AVFoundation
import ArgumentParser
import Foundation

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

  @Option(name: [.long, .customShort("o")], help: "Output folder")
  var destination: String? = nil

  @Flag(
    name: [.long, .customShort("i")],
    help: "Copy or move non-video source files. Only valid when a destination is set.")
  var nonVideo = false

  @Flag(name: [.long, .customShort("r")], help: "Remove source file after processing.")
  var removeOriginal = false

  @Argument(help: "source MP4 file(s)", transform: URL.init(fileURLWithPath:))
  var source: [URL]

  mutating func run() async throws {
    print("Running!")

    print("Make: \(make)")
    print("Model: \(model)")
    print("Destination: \(destination ?? "nil")")
    print("Non-video: \(nonVideo)")
    print("Remove original: \(removeOriginal)")

    for url in source {
      print(url)

      let asset = AVAsset(url: url)
      let metadataFormats = try await asset.load(.availableMetadataFormats)

      for format in metadataFormats {
        let metadata = try await asset.loadMetadata(for: format)

        print("The available metadata format is \(format)")

        // With preamble:
        // [MOV-Movie-UserData] GPS Coordinates → uiso/©xyz
        // [MOV-Movie-UserData] Speed X → uiso/©xsp
        // [MOV-Movie-UserData] Speed Y → uiso/©ysp
        // [MOV-Movie-UserData] Speed Z → uiso/©zsp
        // [MOV-Movie-UserData] Pitch → uiso/©fpt
        // [MOV-Movie-UserData] Yaw → uiso/©fyw
        // [MOV-Movie-UserData] Roll → uiso/©frl
        // [MOV-Movie-UserData] Camera Pitch → uiso/©gpt
        // [MOV-Movie-UserData] Camera Yaw → uiso/©gyw
        // [MOV-Movie-UserData] Camera Roll → uiso/©grl

        // Without preamble:
        // [MOV-Movie-UserData] Model
        // [MOV-Movie-UserData] Serial number

        // Unknown:
        // [MOV-Movie-MovieHeader] Create Date
        // [MOV-Movie-MovieHeader] Modify Date
        // [MOV-Movie-UserData-Meta-ItemList] Comment

        for item in metadata {
          if let data = item.dataValue,
            let identifier = item.identifier?.rawValue.replacingOccurrences(of: "%A9", with: "©")
          {

            let type = Int(data[0])
            let size = Int(data[1])

            guard size > 1 else {
              print("🚫 \(identifier) → No data")
              continue
            }

            if type == 0 {
              let start = 4  // Skip the first four bytes
              let end = 4 + size

              var subdata = data[start..<end]
              let nullEnd = subdata.firstIndex(where: { $0 == 0 }) ?? subdata.endIndex
              subdata = subdata[start..<nullEnd]  // Remove the null bytes

              let hex = subdata.reduce("") { $0 + String(format: "%02x ", $1) }
              let string = String(data: subdata, encoding: .ascii)

              print("✅ \(identifier) → \(string ?? "—") \(size)|\(subdata.count) bytes [\(hex)]")
            } else {
              let hex = data.reduce("") { $0 + String(format: "%02x ", $1) }
              print(
                "😢 \(identifier) → Data: \(String(data: data, encoding: .ascii) ?? "—") [\(hex)]")
            }
          }
        }
      }

      let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("output-\(Int(Date().timeIntervalSince1970))")
        .appendingPathExtension("mp4")

      print("OUTPUT: \(outputURL)")

      let exporter = Exporter()

      let url = await exporter.asyncExport(
        avAsset: asset,
        toFileType: .mp4,
        atURL: outputURL)

      print("Done! \(url?.absoluteString ?? "—")")

      // await export(
      //   video: asset,
      //   withPreset: AVAssetExportPresetHighestQuality,
      //   toFileType: .mov,
      //   atURL: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      //     .appendingPathComponent("export-output")
      //     .appendingPathExtension("mp4"))
    }
  }
}

func export(
  video: AVAsset,
  withPreset preset: String = AVAssetExportPresetHighestQuality,
  toFileType outputFileType: AVFileType = .mov,
  atURL outputURL: URL
) async {

  // Check the compatibility of the preset to export the video to the output file type.
  guard
    await AVAssetExportSession.compatibility(
      ofExportPreset: preset,
      with: video,
      outputFileType: outputFileType)
  else {
    print("The preset can't export the video to the output file type.")
    return
  }

  // Create and configure the export session.
  guard
    let exportSession = AVAssetExportSession(
      asset: video,
      presetName: preset)
  else {
    print("Failed to create export session.")
    return
  }
  exportSession.outputFileType = outputFileType
  exportSession.outputURL = outputURL

  // Convert the video to the output file type and export it to the output URL.
  await exportSession.export()
}
