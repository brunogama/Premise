import Foundation

/// Recorded primitive choices and their associated spans.
public struct ChoiceTrace: Sendable, Codable, Equatable {

  /// The recorded choices.
  public var entries: [Entry]
  /// The recorded spans.
  public var spans: [Span]

  /// Creates a trace from choices and spans.
  public init(entries: [Entry] = [], spans: [Span] = []) {
    self.entries = entries
    self.spans = spans
  }

  /// Appends a choice.
  public mutating func append(_ entry: Entry) {
    entries.append(entry)
  }

  /// Appends a recorded bit draw.
  public mutating func appendBits(count: Int, value: UInt64) {
    entries.append(.bits(BitEntry(count: count, value: value)))
  }

  /// Appends a nonempty span.
  public mutating func append(span: Span) {
    guard span.start < span.end else {
      return
    }

    spans.append(span)
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
      try rejectUnsupportedBlobPrefix(trimmed)
    } else {
      encoded = trimmed
    }

    guard let data = base64URLDecoded(encoded) else {
      throw ChoiceTraceBlobError.invalidBase64
    }
    return try ChoiceTrace(binaryData: data)
  }


  private static func rejectUnsupportedBlobPrefix(
    _ trimmed: String
  ) throws -> Never {
    let first = trimmed.split(separator: ":", maxSplits: 1).first
    let prefix = first.map(String.init) ?? trimmed
    let versionText = prefix.dropFirst("premise-trace-v".count)
    if let version = UInt16(versionText) {
      throw ChoiceTraceBlobError.unsupportedVersion(
        found: version,
        supported: supportedBinaryFormatVersions
      )
    }
    throw ChoiceTraceBlobError.invalidBlobPrefix(prefix)
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
