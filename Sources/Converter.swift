import Foundation

struct ProcessResult {
  let status: Int32
  let output: String
}

protocol ProcessRunning {
  func run(executableURL: URL, arguments: [String]) throws -> ProcessResult
}

struct SystemProcessRunner: ProcessRunning {
  func run(executableURL: URL, arguments: [String]) throws -> ProcessResult {
    let process = Process()
    process.qualityOfService = .userInitiated
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    process.executableURL = executableURL
    process.arguments = arguments

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    return ProcessResult(status: process.terminationStatus, output: output)
  }
}

protocol VideoConverting {
  func convert(input: URL, output: URL) async throws
}

/// Converts input video files to QuickTime MOV while preserving streams and metadata tags.
class Converter: VideoConverting {
  private let processRunner: ProcessRunning

  // MARK: - Initialization

  /// Creates a new converter instance.
  public init(processRunner: ProcessRunning = SystemProcessRunner()) {
    self.processRunner = processRunner
  }

  /// Converts a video file to MOV format with ffmpeg.
  ///
  /// - Parameters:
  ///   - input: Source video URL.
  ///   - output: Destination MOV URL.
  /// - Throws: An error when ffmpeg exits with a non-zero status.
  public func convert(
    input: URL,
    output: URL
  ) async throws {
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

    let result = try processRunner.run(
      executableURL: URL(fileURLWithPath: "/usr/bin/env"),
      arguments: command
    )

    if result.status == 0 {
      print("Conversion succeeded.")
    } else {
      print("Conversion failed with status: \(result.status)")
      print("Error output: \(result.output)")
      throw NSError(
        domain: "fi.matiaskorhonen.dji-gps-metadata",
        code: Int(result.status),
        userInfo: [NSLocalizedDescriptionKey: "Conversion failed with status: \(result.status)"]
      )
    }

    print(result.output)
  }
}
