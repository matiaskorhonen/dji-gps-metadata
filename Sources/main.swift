import Foundation
import ArgumentParser

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
@available(macOS 12, *)
struct DJIMetadataFixer: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "DJI GPS Metadata for Photos.app")

    @Option(name: [.long, .customShort("m")], help: "Device make")
    var make: String = "DJI"

    @Option(name: [.long, .customShort("d")], help: "Device model")
    var model: String = "Mini 2"

    @Option(name: [.long, .customShort("o")], help: "Output folder")
    var destination: String? = nil

    @Flag(name: [.long, .customShort("i")], help: "Copy or move non-video source files. Only valid when a destination is set.")
    var nonVideo = false

    @Flag(name: [.long, .customShort("r")], help: "Remove source file after processing.")
    var removeOriginal = false

    @Argument(help: "source MP4 file(s)", transform: URL.init(fileURLWithPath:))
    var source: [URL]

    mutating func run() throws {
        print("Running!")

        print("Make: \(make)")
        print("Model: \(model)")
        print("Destination: \(destination ?? "nil")")
        print("Non-video: \(nonVideo)")
        print("Remove original: \(removeOriginal)")

        for file in source {
            print(file)
        }
        // let repeatCount = count ?? 2

        // for i in 1...repeatCount {
        //     if includeCounter {
        //         print("\(i): \(phrase)")
        //     } else {
        //         print(phrase)
        //     }
        // }
    }
}
