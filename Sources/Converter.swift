import Foundation

class Converter {
  // MARK: - Initialization

  public init() {
  }

  public func convert(
    input: URL,
    output: URL
  ) async throws {
    let process = Process()
    process.qualityOfService = .userInitiated
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

    let command = [
      "ffmpeg",
      "-i", input.path,
      "-acodec", "copy",
      "-vcodec", "copy",
      "-scodec", "mov_text",
      "-dcodec", "copy",
      "-movflags", "use_metadata_tags",
      "-f", "mov",
      "-y",
      "-nostdin",
      "-hide_banner",
      "-loglevel", "error",
      output.path,
    ]

    print("Command: \(command.joined(separator: " "))")

    process.arguments = command

    try process.run()

    process.waitUntilExit()

    let status = process.terminationStatus

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    if status == 0 {
      print("Conversion succeeded.")
    } else {
      print("Conversion failed with status: \(status)")
      print("Error output: \(output)")
      throw NSError(
        domain: "fi.matiaskorhonen.dji-gps-metadata",
        code: Int(status),
        userInfo: [NSLocalizedDescriptionKey: "Conversion failed with status: \(status)"]
      )
    }

    print(output)
  }
}
