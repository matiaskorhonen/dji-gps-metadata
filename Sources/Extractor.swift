import AVFoundation
import Bamf

struct MetadataTemplate {
  var identifier: AVMetadataIdentifier
  var dataType: String
}

public struct Extractor {
  private static let quickTimeDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    formatter.timeZone = TimeZone.current
    return formatter
  }()

  private static let sourceQuickTimeDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
    formatter.timeZone = TimeZone.current
    return formatter
  }()

  private static let sourceFFmpegDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.timeZone = TimeZone.current
    return formatter
  }()

  private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let iso8601Standard: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

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
      identifier: .quickTimeMetadataMake,
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    // Device model
    "model": MetadataTemplate(
      identifier: .quickTimeMetadataModel,
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    // File comment
    "comment": MetadataTemplate(
      identifier: .quickTimeMetadataComment,
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    "title": MetadataTemplate(
      identifier: .quickTimeMetadataTitle,
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    "description": MetadataTemplate(
      identifier: .quickTimeMetadataDescription,
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    // Serial number (closest native mapping)
    "uiso/©csn": MetadataTemplate(
      identifier: .quickTimeMetadataCameraIdentifier,
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    // DJI telemetry fields persisted as custom mdta keys
    "uiso/©xsp": MetadataTemplate(
      identifier: AVMetadataIdentifier(rawValue: "mdta/com.dji.speed.x"),
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    "uiso/©ysp": MetadataTemplate(
      identifier: AVMetadataIdentifier(rawValue: "mdta/com.dji.speed.y"),
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    "uiso/©zsp": MetadataTemplate(
      identifier: AVMetadataIdentifier(rawValue: "mdta/com.dji.speed.z"),
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    "uiso/©fpt": MetadataTemplate(
      identifier: AVMetadataIdentifier(rawValue: "mdta/com.dji.flight.pitch"),
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    "uiso/©fyw": MetadataTemplate(
      identifier: AVMetadataIdentifier(rawValue: "mdta/com.dji.flight.yaw"),
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    "uiso/©frl": MetadataTemplate(
      identifier: AVMetadataIdentifier(rawValue: "mdta/com.dji.flight.roll"),
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    "uiso/©gpt": MetadataTemplate(
      identifier: AVMetadataIdentifier(rawValue: "mdta/com.dji.gimbal.pitch"),
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    "uiso/©gyw": MetadataTemplate(
      identifier: AVMetadataIdentifier(rawValue: "mdta/com.dji.gimbal.yaw"),
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
    "uiso/©grl": MetadataTemplate(
      identifier: AVMetadataIdentifier(rawValue: "mdta/com.dji.gimbal.roll"),
      dataType: kCMMetadataBaseDataType_UTF8 as String
    ),
  ]

  public static func extractMetadata(from asset: AVAsset)
    async throws -> [String: String]
  {
    var parsedMetadata = try extractUserDataMetadata(from: asset)
    let avMetadata = try await extractAVMetadata(from: asset)

    for (key, value) in avMetadata where !key.hasPrefix("uiso/") && parsedMetadata[key] == nil {
      parsedMetadata[key] = value
    }

    if parsedMetadata["createDate"] == nil {
      let creationDateItem = try await asset.load(.creationDate)
      if let creationDateItem {
        if let dateValue = creationDateItem.dateValue {
          parsedMetadata["createDate"] = formatQuickTimeDate(dateValue)
        } else if let stringValue = creationDateItem.stringValue,
          !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
          parsedMetadata["createDate"] = stringValue
        }
      }
    }

    if parsedMetadata["createDate"] == nil {
      parsedMetadata["createDate"] =
        parsedMetadata["mdta/com.apple.quicktime.creationdate"]
        ?? parsedMetadata["com.apple.quicktime.creationdate"]
        ?? parsedMetadata["creationDate"]
        ?? parsedMetadata["creation_time"]
    }

    if parsedMetadata["comment"] == nil {
      parsedMetadata["comment"] =
        parsedMetadata["mdta/com.apple.quicktime.comment"]
        ?? parsedMetadata["com.apple.quicktime.comment"]
        ?? parsedMetadata["comment"]
    }

    return parsedMetadata
  }

  private static func extractUserDataMetadata(from asset: AVAsset) throws -> [String: String] {
    guard let urlAsset = asset as? AVURLAsset else {
      return [:]
    }

    let bamf = try Bamf(urlAsset.url)
    var parsedMetadata: [String: String] = [:]

    if let udta = bamf.findAtom(ofType: Atom.UDTA.self) {
      for userDataAtom in udta.userData {
        if userDataAtom.type == "meta" {
          if parsedMetadata["comment"] == nil,
            let comment = extractComment(from: userDataAtom)
          {
            parsedMetadata["comment"] = comment
          }
          continue
        }

        let identifier = "uiso/\(userDataAtom.type)"
        if let value = decodeUserDataValue(from: userDataAtom.data) {
          parsedMetadata[identifier] = value
        }
      }
    }

    return parsedMetadata
  }

  private static func extractAVMetadata(from asset: AVAsset)
    async throws -> [String: String]
  {
    var parsedMetadata: [String: String] = [:]
    let metadataFormats = try await asset.load(.availableMetadataFormats)

    for format in metadataFormats {
      let metadata = try await asset.loadMetadata(for: format)

      // print("The available metadata format is \(format)")

      for item in metadata {
        let value = metadataStringValue(from: item)
        guard let value, !value.isEmpty else {
          continue
        }

        if let identifier = item.identifier?.rawValue.replacingOccurrences(of: "%A9", with: "©") {
          parsedMetadata[identifier] = value
        }

        if let key = item.key as? String, !key.isEmpty {
          parsedMetadata[key] = value
        }

        if let commonKey = item.commonKey?.rawValue, !commonKey.isEmpty {
          parsedMetadata[commonKey] = value
        }
      }
    }

    return parsedMetadata
  }

  private static func metadataStringValue(from item: AVMetadataItem) -> String? {
    if let stringValue = item.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
      !stringValue.isEmpty
    {
      return stringValue
    }

    if let dateValue = item.dateValue {
      return formatQuickTimeDate(dateValue)
    }

    guard let data = item.dataValue, data.count >= 2 else {
      return nil
    }

    let type = Int(data[data.startIndex])
    let size = Int(data[data.startIndex + 1])

    guard size > 1 else {
      return nil
    }

    if type == 0 {
      let start = data.startIndex + 4
      let end = min(start + size, data.endIndex)
      guard start < end else {
        return nil
      }

      let subdata = data[start..<end]
      let nullEnd = subdata.firstIndex(where: { $0 == 0 }) ?? subdata.endIndex
      return String(data: subdata[subdata.startIndex..<nullEnd], encoding: .utf8)
    }

    let end = data.firstIndex(where: { $0 == 0 }) ?? data.endIndex
    return String(data: data[data.startIndex..<end], encoding: .utf8)
  }

  private static func formatQuickTimeDate(_ date: Date) -> String {
    quickTimeDateFormatter.string(from: date)
  }

  private static func decodeUserDataValue(from data: Data) -> String? {
    guard !data.isEmpty else {
      return nil
    }

    var candidates: [String] = []

    if data.count >= 2 {
      let type = Int(data[data.startIndex])
      let size = Int(data[data.startIndex + 1])

      if type == 0 && size > 1 {
        let payloadStart = data.startIndex + 4
        let payloadEnd = min(payloadStart + size, data.endIndex)

        if payloadStart < payloadEnd {
          let payload = data[payloadStart..<payloadEnd]
          if let decoded = decodeNullTerminatedString(from: payload) {
            candidates.append(decoded)
          }
        }
      }
    }

    if data.count > 4 {
      let payload = data[(data.startIndex + 4)..<data.endIndex]
      if let decoded = decodeNullTerminatedString(from: payload) {
        candidates.append(decoded)
      }
    }

    if let nullIndex = data.firstIndex(of: 0), nullIndex > data.startIndex {
      let payload = data[data.startIndex..<nullIndex]
      if let decoded = String(data: payload, encoding: .utf8) {
        candidates.append(decoded)
      }
    }

    if let decoded = String(data: data, encoding: .utf8) {
      candidates.append(decoded)
    }

    if let printableTail = longestPrintableASCIIRun(in: data) {
      candidates.append(printableTail)
    }

    return
      candidates
      .map({ $0.trimmingCharacters(in: .controlCharacters) })
      .filter({ !$0.isEmpty })
      .max(by: { $0.count < $1.count })
  }

  private static func decodeNullTerminatedString(from data: Data.SubSequence) -> String? {
    guard !data.isEmpty else {
      return nil
    }

    let end = data.firstIndex(of: 0) ?? data.endIndex
    let payload = data[data.startIndex..<end]
    guard !payload.isEmpty else {
      return nil
    }

    return String(data: payload, encoding: .utf8)
  }

  private static func extractComment(from atom: Atom) -> String? {
    if atom.type == "©cmt" {
      for child in atom.displayChildren where child.type == "data" {
        if let comment = decodeUserDataValue(from: child.data), !comment.isEmpty {
          return comment
        }
      }
    }

    for child in atom.displayChildren {
      if let comment = extractComment(from: child) {
        return comment
      }
    }

    return nil
  }

  private static func longestPrintableASCIIRun(in data: Data) -> String? {
    var best: [UInt8] = []
    var current: [UInt8] = []

    for byte in data {
      if (32...126).contains(byte) {
        current.append(byte)
      } else {
        if current.count > best.count {
          best = current
        }
        current.removeAll(keepingCapacity: true)
      }
    }

    if current.count > best.count {
      best = current
    }

    guard !best.isEmpty else {
      return nil
    }

    return String(decoding: best, as: UTF8.self)
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

    var items: [AVMetadataItem] = []

    for (key, value) in metadata {
      guard let template = self.knownFormats[key] else {
        continue
      }

      switch key {
      case "uiso/©xyz":
        let location = normalizeISO6709(value)

        items.append(
          makeMetadataItem(
            identifier: .quickTimeMetadataLocationISO6709,
            value: location,
            dataType: kCMMetadataDataType_QuickTimeMetadataLocation_ISO6709 as String
          )
        )
        items.append(
          makeMetadataItem(
            identifier: .quickTimeUserDataLocationISO6709,
            value: location,
            dataType: kCMMetadataBaseDataType_UTF8 as String
          )
        )

      case "createDate":
        items.append(
          makeMetadataItem(
            identifier: .quickTimeMetadataCreationDate,
            value: normalizeCreationDate(value),
            dataType: kCMMetadataBaseDataType_UTF8 as String
          )
        )

      case "comment":
        items.append(
          makeMetadataItem(
            identifier: .quickTimeMetadataComment,
            value: value,
            dataType: kCMMetadataBaseDataType_UTF8 as String
          )
        )
        items.append(
          makeMetadataItem(
            identifier: .quickTimeUserDataComment,
            value: value,
            dataType: kCMMetadataBaseDataType_UTF8 as String
          )
        )

      default:
        items.append(
          makeMetadataItem(
            identifier: template.identifier,
            value: value,
            dataType: template.dataType
          )
        )
      }
    }

    return items
  }

  private static func makeMetadataItem(
    identifier: AVMetadataIdentifier,
    value: String,
    dataType: String
  ) -> AVMetadataItem {
    let item = AVMutableMetadataItem()
    item.identifier = identifier
    item.value = value as (NSCopying & NSObjectProtocol)
    item.dataType = dataType
    return item.copy() as! AVMetadataItem
  }

  private static func normalizeISO6709(_ value: String) -> String {
    if let iso6709 = try? ISO6709(value) {
      return iso6709.normalizedString
    }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return trimmed
    }

    return trimmed.hasSuffix("/") ? trimmed : "\(trimmed)/"
  }

  private static func normalizeCreationDate(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmed.isEmpty {
      return trimmed
    }

    if let date = sourceQuickTimeDateFormatter.date(from: trimmed)
      ?? sourceFFmpegDateFormatter.date(from: trimmed)
    {
      return formatQuickTimeDate(date)
    }

    if let date = iso8601WithFractionalSeconds.date(from: trimmed)
      ?? iso8601Standard.date(from: trimmed)
    {
      return formatQuickTimeDate(date)
    }

    return trimmed
  }
}
