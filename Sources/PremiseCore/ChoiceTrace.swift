import Foundation

public struct ChoiceTrace: Sendable, Codable, Equatable {
  public enum Entry: Sendable, Codable, Equatable {
    case bits(BitEntry)
    case integer(UInt64)
    case boolean(Bool)
    case bytes([UInt8])
  }

  public struct BitEntry: Sendable, Codable, Equatable {
    public var count: Int
    public var value: UInt64

    public init(count: Int, value: UInt64) {
      self.count = count
      self.value = value
    }
  }

  public struct Span: Sendable, Codable, Equatable {
    public var label: String?
    public var start: Int
    public var end: Int

    public init(label: String? = nil, start: Int, end: Int) {
      self.label = label
      self.start = start
      self.end = end
    }
  }

  public var entries: [Entry]
  public var spans: [Span]

  public init(entries: [Entry] = [], spans: [Span] = []) {
    self.entries = entries
    self.spans = spans
  }

  public mutating func append(_ entry: Entry) {
    entries.append(entry)
  }

  public mutating func appendBits(count: Int, value: UInt64) {
    entries.append(.bits(BitEntry(count: count, value: value)))
  }

  public mutating func append(span: Span) {
    guard span.start < span.end else {
      return
    }

    spans.append(span)
  }
}

/// Errors raised while decoding or encoding stable Premise replay blobs.
public enum ChoiceTraceBlobError: Error, Equatable, Sendable, CustomStringConvertible {
  /// The binary payload does not start with Premise's trace magic header.
  case badMagic

  /// The binary payload uses a trace version this runtime cannot decode.
  case unsupportedVersion(found: UInt16, supported: ClosedRange<UInt16>)

  /// The binary payload ended before a complete field could be decoded.
  case truncated

  /// The copy-paste blob did not contain valid base64-url data.
  case invalidBase64

  /// The blob prefix is not one of the supported Premise replay blob prefixes.
  case invalidBlobPrefix(String)

  /// The payload is structurally invalid.
  case malformed(String)

  public var description: String {
    switch self {
    case .badMagic:
      return "Replay blob does not use the Premise trace magic header."
    case .unsupportedVersion(let found, let supported):
      return "Unsupported Premise trace blob version: found=\(found), supported=\(supported)."
    case .truncated:
      return "Replay blob ended before a complete trace could be decoded."
    case .invalidBase64:
      return "Replay blob does not contain valid base64-url data."
    case .invalidBlobPrefix(let prefix):
      return "Unsupported Premise replay blob prefix: \(prefix)."
    case .malformed(let message):
      return "Malformed Premise replay blob: \(message)"
    }
  }
}

public extension ChoiceTrace {
  /// Magic header used by stable binary replay blobs: `PTRC`.
  static let binaryMagic: [UInt8] = [0x50, 0x54, 0x52, 0x43]

  /// Current stable binary replay blob version.
  static let binaryFormatVersion: UInt16 = 1

  /// Versions this runtime can decode.
  static let supportedBinaryFormatVersions: ClosedRange<UInt16> = 1...1

  /// Prefix used for copy-paste replay blobs in diagnostics.
  static let reproductionBlobPrefix = "premise-trace-v1:"

  /// Encodes this trace into Premise's stable binary trace format.
  func binaryEncoded() throws -> Data {
    var encoder = ChoiceTraceBinaryEncoder()
    try encoder.encode(self)
    return encoder.data
  }

  /// Decodes a trace from Premise's stable binary trace format.
  init(binaryData: Data) throws {
    var decoder = ChoiceTraceBinaryDecoder(data: binaryData)
    self = try decoder.decodeTrace()
  }

  /// Returns a copy-paste-safe replay blob for diagnostics and tools.
  func reproductionBlob() throws -> String {
    let encoded = try binaryEncoded()
    return Self.reproductionBlobPrefix + Self.base64URLEncoded(encoded)
  }

  /// Decodes a copy-paste replay blob produced by ``reproductionBlob()``.
  static func decodeReproductionBlob(_ blob: String) throws -> ChoiceTrace {
    let trimmed = blob.trimmingCharacters(in: .whitespacesAndNewlines)
    let encoded: String

    if trimmed.hasPrefix(reproductionBlobPrefix) {
      encoded = String(trimmed.dropFirst(reproductionBlobPrefix.count))
    } else if trimmed.hasPrefix("premise-trace-v") {
      let prefix = trimmed.split(separator: ":", maxSplits: 1).first.map(String.init) ?? trimmed
      let versionText = prefix.dropFirst("premise-trace-v".count)
      if let version = UInt16(versionText) {
        throw ChoiceTraceBlobError.unsupportedVersion(
          found: version,
          supported: supportedBinaryFormatVersions
        )
      }
      throw ChoiceTraceBlobError.invalidBlobPrefix(prefix)
    } else {
      encoded = trimmed
    }

    guard let data = base64URLDecoded(encoded) else {
      throw ChoiceTraceBlobError.invalidBase64
    }
    return try ChoiceTrace(binaryData: data)
  }

  private static func base64URLEncoded(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  private static func base64URLDecoded(_ string: String) -> Data? {
    var base64 =
      string
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")

    let remainder = base64.count % 4
    if remainder > 0 {
      base64 += String(repeating: "=", count: 4 - remainder)
    }

    return Data(base64Encoded: base64)
  }
}

private struct ChoiceTraceBinaryEncoder {
  private enum EntryTag: UInt8 {
    case bits = 0
    case integer = 1
    case boolean = 2
    case bytes = 3
  }

  var data = Data()

  mutating func encode(_ trace: ChoiceTrace) throws {
    data.append(contentsOf: ChoiceTrace.binaryMagic)
    appendUInt16(ChoiceTrace.binaryFormatVersion)
    try appendCount(trace.entries.count, label: "entry count")
    for entry in trace.entries {
      try append(entry)
    }
    try appendCount(trace.spans.count, label: "span count")
    for span in trace.spans {
      try append(span, entryCount: trace.entries.count)
    }
  }

  private mutating func append(_ entry: ChoiceTrace.Entry) throws {
    switch entry {
    case .bits(let bitEntry):
      guard bitEntry.count >= 0 else {
        throw ChoiceTraceBlobError.malformed("bit count must be non-negative")
      }
      data.append(EntryTag.bits.rawValue)
      try appendCount(bitEntry.count, label: "bit count")
      appendUInt64(bitEntry.value)

    case .integer(let value):
      data.append(EntryTag.integer.rawValue)
      appendUInt64(value)

    case .boolean(let value):
      data.append(EntryTag.boolean.rawValue)
      data.append(value ? 1 : 0)

    case .bytes(let bytes):
      data.append(EntryTag.bytes.rawValue)
      try appendCount(bytes.count, label: "byte count")
      data.append(contentsOf: bytes)
    }
  }

  private mutating func append(
    _ span: ChoiceTrace.Span,
    entryCount: Int
  ) throws {
    guard span.start >= 0, span.end >= span.start, span.end <= entryCount else {
      throw ChoiceTraceBlobError.malformed("span bounds are outside trace entries")
    }

    if let label = span.label {
      data.append(1)
      let labelData = Data(label.utf8)
      try appendCount(labelData.count, label: "span label byte count")
      data.append(labelData)
    } else {
      data.append(0)
    }

    try appendCount(span.start, label: "span start")
    try appendCount(span.end, label: "span end")
  }

  private mutating func appendCount(_ count: Int, label: String) throws {
    guard count >= 0, count <= Int(UInt32.max) else {
      throw ChoiceTraceBlobError.malformed("\(label) does not fit in UInt32")
    }
    appendUInt32(UInt32(count))
  }

  private mutating func appendUInt16(_ value: UInt16) {
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8(value & 0xff))
  }

  private mutating func appendUInt32(_ value: UInt32) {
    data.append(UInt8((value >> 24) & 0xff))
    data.append(UInt8((value >> 16) & 0xff))
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8(value & 0xff))
  }

  private mutating func appendUInt64(_ value: UInt64) {
    for shift in stride(from: 56, through: 0, by: -8) {
      data.append(UInt8((value >> UInt64(shift)) & 0xff))
    }
  }
}

private struct ChoiceTraceBinaryDecoder {
  private enum EntryTag: UInt8 {
    case bits = 0
    case integer = 1
    case boolean = 2
    case bytes = 3
  }

  private let bytes: [UInt8]
  private var offset = 0

  init(data: Data) {
    self.bytes = Array(data)
  }

  mutating func decodeTrace() throws -> ChoiceTrace {
    try decodeMagic()
    let version = try readUInt16()
    guard ChoiceTrace.supportedBinaryFormatVersions.contains(version) else {
      throw ChoiceTraceBlobError.unsupportedVersion(
        found: version,
        supported: ChoiceTrace.supportedBinaryFormatVersions
      )
    }

    let entryCount = try readCount(label: "entry count")
    var entries: [ChoiceTrace.Entry] = []
    entries.reserveCapacity(entryCount)
    for _ in 0..<entryCount {
      entries.append(try decodeEntry())
    }

    let spanCount = try readCount(label: "span count")
    var spans: [ChoiceTrace.Span] = []
    spans.reserveCapacity(spanCount)
    for _ in 0..<spanCount {
      spans.append(try decodeSpan(entryCount: entryCount))
    }

    guard offset == bytes.count else {
      throw ChoiceTraceBlobError.malformed("trailing bytes after trace payload")
    }

    return ChoiceTrace(entries: entries, spans: spans)
  }

  private mutating func decodeMagic() throws {
    guard bytes.count >= ChoiceTrace.binaryMagic.count else {
      throw ChoiceTraceBlobError.truncated
    }
    let magic = Array(bytes[0..<ChoiceTrace.binaryMagic.count])
    guard magic == ChoiceTrace.binaryMagic else {
      throw ChoiceTraceBlobError.badMagic
    }
    offset = ChoiceTrace.binaryMagic.count
  }

  private mutating func decodeEntry() throws -> ChoiceTrace.Entry {
    let rawTag = try readUInt8()
    guard let tag = EntryTag(rawValue: rawTag) else {
      throw ChoiceTraceBlobError.malformed("unknown entry tag \(rawTag)")
    }

    switch tag {
    case .bits:
      let count = try readCount(label: "bit count")
      let value = try readUInt64()
      return .bits(ChoiceTrace.BitEntry(count: count, value: value))

    case .integer:
      return .integer(try readUInt64())

    case .boolean:
      let rawValue = try readUInt8()
      switch rawValue {
      case 0:
        return .boolean(false)
      case 1:
        return .boolean(true)
      default:
        throw ChoiceTraceBlobError.malformed("boolean value must be 0 or 1")
      }

    case .bytes:
      let count = try readCount(label: "byte count")
      return .bytes(try readBytes(count))
    }
  }

  private mutating func decodeSpan(entryCount: Int) throws -> ChoiceTrace.Span {
    let hasLabel = try readUInt8()
    let label: String?
    switch hasLabel {
    case 0:
      label = nil
    case 1:
      let labelLength = try readCount(label: "span label byte count")
      let labelBytes = try readBytes(labelLength)
      guard let decoded = String(bytes: labelBytes, encoding: .utf8) else {
        throw ChoiceTraceBlobError.malformed("span label is not valid UTF-8")
      }
      label = decoded
    default:
      throw ChoiceTraceBlobError.malformed("span label marker must be 0 or 1")
    }

    let start = try readCount(label: "span start")
    let end = try readCount(label: "span end")
    guard start <= end, end <= entryCount else {
      throw ChoiceTraceBlobError.malformed("span bounds are outside trace entries")
    }
    return ChoiceTrace.Span(label: label, start: start, end: end)
  }

  private mutating func readCount(label: String) throws -> Int {
    let value = try readUInt32()
    guard UInt64(value) <= UInt64(Int.max) else {
      throw ChoiceTraceBlobError.malformed("\(label) does not fit in Int")
    }
    return Int(value)
  }

  private mutating func readBytes(_ count: Int) throws -> [UInt8] {
    guard offset + count <= bytes.count else {
      throw ChoiceTraceBlobError.truncated
    }
    let result = Array(bytes[offset..<(offset + count)])
    offset += count
    return result
  }

  private mutating func readUInt8() throws -> UInt8 {
    guard offset < bytes.count else {
      throw ChoiceTraceBlobError.truncated
    }
    defer { offset += 1 }
    return bytes[offset]
  }

  private mutating func readUInt16() throws -> UInt16 {
    let high = UInt16(try readUInt8())
    let low = UInt16(try readUInt8())
    return (high << 8) | low
  }

  private mutating func readUInt32() throws -> UInt32 {
    var value: UInt32 = 0
    for _ in 0..<4 {
      value = (value << 8) | UInt32(try readUInt8())
    }
    return value
  }

  private mutating func readUInt64() throws -> UInt64 {
    var value: UInt64 = 0
    for _ in 0..<8 {
      value = (value << 8) | UInt64(try readUInt8())
    }
    return value
  }
}
