# DJI GPS Metadata

Write GPS location metadata to video files from a DJI drone in a way that Apple's Photos.app knows how to parse.

The GPS location is extracted from the original MP4 files using exiftool and the MP4 files are converted to QuickTime videos (`.mov`) *without* re-encoding them. Subtitles are preserved, if present.

*Note: this has only been tested using recordings from a DJI Mini 2 as that's the only drone I have access to*

## Dependencies

* bash
* exiftool (`brew install exiftool`)
* ffmpeg (`brew install ffmpeg`)
* avmetareadwrite (from `xcode-select --install` or from Xcode)

### Development dependencies

* Docker
  * argbash
  * shfmt
  * shellcheck

Run `./scripts/check-and-format` before committing changes.

## Usage

```
» ./dji-gps-metadata.sh  -h
DJI GPS Metadata for Photos.app
Usage: ./dji-gps-metadata.sh [-m|--make <arg>] [-d|--model <arg>] [-r|--(no-)remove-original] [-h|--help] <filename-1> [<filename-2>] ... [<filename-n>] ...
	<filename>: source MP4 file
	-m, --make: Device make (default: 'DJI')
	-d, --model: Device model (default: 'Mini 2')
	-r, --remove-original, --no-remove-original: Remove original MP4s after processing (off by default)
	-h, --help: Prints help
```

## MIT License

Copyright (c) 2022 Matias Korhonen. See LICENSE for details.
