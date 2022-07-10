# DJI GPS Metadata

Write GPS location metadata to video files in a way that Photos.app knows how to parse.

## Dependencies

* bash
* ffmpeg (`brew install ffmpeg`)
* avmetareadwrite (from `xcode-select --install` or from Xcode)

## Usage

```
» ./dji-gps-metadata.sh  -h
DJI GPS Metadata for Photos.app
Usage: ./dji-gps-metadata.sh [-m|--make <arg>] [-d|--model <arg>] [-h|--help] <filename-1> [<filename-2>] ... [<filename-n>] ...
  <filename>: source MP4 file
  -m, --make: Device make (default: 'DJI')
  -d, --model: Device model (default: 'Mini 2')
  -h, --help: Prints help
```
