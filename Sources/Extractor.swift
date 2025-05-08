import AVFoundation

struct MetadataTemplate {
  var identifier: AVMetadataIdentifier
  var dataType: String

  // func standardDecode(data: Data) -> String? {
  //   let type = Int(data[0])
  //   let size = Int(data[1])

  //   guard size > 0 else {
  //     return nil
  //   }

  //   guard type == 0 else {
  //     return nil
  //   }

  //   let start = 4  // Skip the first four bytes
  //   let end = 4 + size - 1

  //   if end > data.count {
  //     return nil
  //   }

  //   var subdata = data[start..<end]
  //   let nullEnd = subdata.firstIndex(where: { $0 == 0 }) ?? subdata.endIndex
  //   subdata = subdata[start..<nullEnd]  // Remove the null bytes

  //   return String(data: subdata, encoding: .ascii)
  // }

  // func nonStandardDecode(data: Data) -> String {
  //   return ""
  // }
}

public struct Extractor {
  // ExifTool output and the corresponding uiso identifiers:
  //
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
  //
  // Without preamble:
  // [MOV-Movie-UserData] Model
  // [MOV-Movie-UserData] Serial number
  //
  // Unknown:
  // [MOV-Movie-MovieHeader] Create Date
  // [MOV-Movie-MovieHeader] Modify Date
  // [MOV-Movie-UserData-Meta-ItemList] Comment

  static let knownFormats: [String: MetadataTemplate] = [
    // GPS Coordinates
    "uiso/©xyz": MetadataTemplate(
      identifier: .quickTimeMetadataLocationISO6709,
      dataType: kCMMetadataDataType_QuickTimeMetadataLocation_ISO6709 as String
    ),
    // File create date
    "createDate": MetadataTemplate(
      identifier: .quickTimeMetadataCreationDate,
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    // Device make
    "make": MetadataTemplate(
      identifier: .commonIdentifierMake,
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    // Device model
    "model": MetadataTemplate(
      identifier: .commonIdentifierModel,
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    // File comment
    "comment": MetadataTemplate(
      identifier: .commonIdentifierDescription,
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    "title": MetadataTemplate(
      identifier: .commonIdentifierTitle,
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    "description": MetadataTemplate(
      identifier: .commonIdentifierDescription,
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    // Other fields that can be read but don't have a known AVMetadataIdentifier:
    //
    // uiso/©xsp → Speed X
    // uiso/©ysp → Speed Y
    // uiso/©zsp → Speed Z
    // uiso/©fpt → Pitch
    // uiso/©fyw → Yaw
    // uiso/©frl → Roll
    // uiso/©gpt → Camera Pitch
    // uiso/©gyw → Camera Yaw
    // uiso/©grl → Camera Roll
    // uiso/©csn → Serial number
    // uiso/©mdl → Model number
  ]

  public static func extractMetadata(from asset: AVAsset)
    async throws -> [String: String]
  {
    var parsedMetadata: [String: String] = [:]
    let metadataFormats = try await asset.load(.availableMetadataFormats)

    for format in metadataFormats {
      let metadata = try await asset.loadMetadata(for: format)

      // print("The available metadata format is \(format)")

      for item in metadata {
        if let data = item.dataValue,
          let identifier = item.identifier?.rawValue.replacingOccurrences(of: "%A9", with: "©")
        {

          let type = Int(data[0])
          let size = Int(data[1])

          guard size > 1 else {
            // print("🚫 \(identifier) → No data")
            continue
          }

          if type == 0 {
            let start = 4  // Skip the first four bytes
            let end = 4 + size

            var subdata = data[start..<end]
            let nullEnd = subdata.firstIndex(where: { $0 == 0 }) ?? subdata.endIndex
            subdata = subdata[start..<nullEnd]  // Remove the null bytes

            // let hex = subdata.reduce("") { $0 + String(format: "%02x ", $1) }
            //   .trimmingCharacters(in: .whitespacesAndNewlines)
            let string = String(data: subdata, encoding: .utf8)

            parsedMetadata[identifier] = string

            // print("✅ \(identifier) → \(string ?? "—") \(size)|\(subdata.count) bytes [\(hex)]")
          } else {
            let start = 0
            let end = data.firstIndex(where: { $0 == 0 }) ?? data.endIndex
            let subdata = data[start..<end]  // Read until the first null or the end
            let string = String(data: subdata, encoding: .utf8)

            parsedMetadata[identifier] = string
          }
        }
      }
    }

    return parsedMetadata
  }

  public static func extractItems(from asset: AVAsset, make: String?, model: String?) async throws
    -> [AVMetadataItem]
  {
    var metadata = try await self.extractMetadata(from: asset)

    metadata["make"] = make
    metadata["model"] = model

    if let modelNumber = metadata["uiso/©mdl"],
      let device = DeviceList.lookup(for: modelNumber)
    {
      if metadata["make"] == nil {
        metadata["make"] = device.make
      }
      if metadata["model"] == nil {
        metadata["model"] = device.model
      }
    }

    metadata["description"] = "Test description"
    metadata["title"] = "Test title"

    // let item = AVMutableMetadataItem()
    // // item.dataType = kCMMetadataBaseDataType_RawData as String
    // item.identifier = .iTunesMetadataDescription
    // item.value = Data("Some value".utf8) as NSData

    // let model = "Creator"
    // let modelItem = AVMutableMetadataItem()
    // item.identifier = .iTunesMetadataCredits
    // modelItem.value = model as (NSCopying & NSObjectProtocol)

    let items: [AVMetadataItem] = metadata.compactMap { (key: String, value: String) in
      if let template = self.knownFormats[key] {
        let item = AVMutableMetadataItem()
        item.identifier = template.identifier
        item.value = value as (NSCopying & NSObjectProtocol)
        item.dataType = template.dataType
        item.locale = Locale.current
        item.extraAttributes = nil
        item.extendedLanguageTag = "und"

        return (item.copy() as! AVMetadataItem)
      } else {
        return nil
      }
    }

    // items.append(item)
    // items.append(modelItem)

    // TODO: figure out why the make and model aren't being persisted
    // print(items)

    return items
  }
}
