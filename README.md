# DJI GPS Metadata

Write GPS location metadata to video files from a DJI drone in a way that Apple's Photos.app knows how to parse.

The GPS location is extracted from the original MP4 files using exiftool and the MP4 files are converted to QuickTime videos (`.mov`) *without* re-encoding them. Subtitles are preserved, if present.

*Note: this has only been tested using recordings from a DJI Mini 2 as that's the only drone I have access to*

## Dependencies

<!-- TODO: Update dependencies -->

## Usage

<!-- TODO: Update the usage -->

## Sample files

Video files used for testing (under `Tests/Resources`):

* `DJI_0007.MP4`: Unmodified 4K video recording from a DJI Mini 2
* `DJI_0007-with-audio.MP4`: 4K video with an added audio track*
* `DJI_0007.MOV`: 4K video converted to a QuickTime movie file
* `DJI_0010-with-audio.MP4`: Unmodified 4K video recording from a DJI Mini 2
* `DJI_0010.MP4`: 4K video with an added audio track*

\* Source: <https://archive.org/details/PachelbelsCanoninD>


## MIT License

Copyright (c) 2022 Matias Korhonen. See LICENSE for details.
