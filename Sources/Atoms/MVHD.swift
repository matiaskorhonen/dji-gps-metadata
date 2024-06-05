import Foundation

extension Atom {
  class MVHD: Atom {
    var version: UInt8 {
      return UInt8(data[data.startIndex + 8])
    }
    var flags: [UInt8] {
      [
        UInt8(data[data.startIndex + 9]),
        UInt8(data[data.startIndex + 10]),
        UInt8(data[data.startIndex + 11]),
      ]
    }
    var creationTime: Date {
      let timeBytes = [UInt8](data[(data.startIndex + 12)..<(data.startIndex + 16)])
      let time = timeBytes.reduce(0) { soFar, byte in
        return soFar << 8 | UInt32(byte)
      }

      // The difference between the Unix timestamp epoch (1970) and the Mac
      // timestamp epoch (1904) is 2082844800 seconds
      return Date(timeIntervalSince1970: TimeInterval(time - 2_082_844_800))
    }
    var modificationTime: Date {
      let timeBytes = [UInt8](data[(data.startIndex + 16)..<(data.startIndex + 20)])

      let time = timeBytes.reduce(0) { soFar, byte in
        return soFar << 8 | UInt32(byte)
      }

      // The difference between the Unix timestamp epoch (1970) and the Mac
      // timestamp epoch (1904) is 2082844800 seconds
      return Date(timeIntervalSince1970: TimeInterval(time - 2_082_844_800))
    }
    var timeScale: UInt32 {
      return 0
    }
    var duration: UInt32 {
      return 0
    }
    var preferredRate: UInt32 {
      return 0
    }
    var preferredVolume: Float {
      return 0
    }
    var nextTrackID: UInt32 {
      return 0
    }

    override var debugDescription: String {
      return """
        Atom(
          type=\(type),
          children=\(children.count)
          version=\(version)
          flags=\(flags)
          creationTime=\(creationTime)
          modificationTime=\(modificationTime)
          timeScale=\(timeScale)
          duration=\(duration)
          preferredRate=\(preferredRate)
          preferredVolume=\(preferredVolume)
          nextTrackID=\(nextTrackID)
        )
        """
    }
  }
}
