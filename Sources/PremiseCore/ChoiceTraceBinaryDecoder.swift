import Foundation
struct ChoiceTraceBinaryDecoder {

  private let bytes: [UInt8]
  private var offset = 0

  init(data: Data) {
    self.bytes = Array(data)
  }

  mutating func decodeTrace() throws -> ChoiceTrace {
    try decodeHeader()

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


  private mutating func decodeHeader() throws {
    try decodeMagic()
    let version = try readUInt16()
    guard ChoiceTrace.supportedBinaryFormatVersions.contains(version) else {
      throw ChoiceTraceBlobError.unsupportedVersion(
        found: version,
        supported: ChoiceTrace.supportedBinaryFormatVersions
      )
    }
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
    guard let tag = ChoiceTraceEntryTag(rawValue: rawTag) else {
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
      return .boolean(try decodeBoolean())

    case .bytes:
      let count = try readCount(label: "byte count")
      return .bytes(try readBytes(count))
    }
  }


  private mutating func decodeBoolean() throws -> Bool {
    switch try readUInt8() {
    case 0: return false
    case 1: return true
    default:
      throw ChoiceTraceBlobError.malformed("boolean value must be 0 or 1")
    }
  }
  private mutating func decodeSpan(entryCount: Int) throws -> ChoiceTrace.Span {
    let hasLabel = try readUInt8()
    let label: String?
    switch hasLabel {
    case 0:
      label = nil
    case 1:
      label = try decodeLabel()
    default:
      throw ChoiceTraceBlobError.malformed("span label marker must be 0 or 1")
    }

    let start = try readCount(label: "span start")
    let end = try readCount(label: "span end")
    guard start <= end, end <= entryCount else {
      throw ChoiceTraceBlobError.malformed(
        "span bounds are outside trace entries"
      )
    }
    return ChoiceTrace.Span(label: label, start: start, end: end)
  }


  private mutating func decodeLabel() throws -> String {
    let length = try readCount(label: "span label byte count")
    let labelBytes = try readBytes(length)
    guard let decoded = String(bytes: labelBytes, encoding: .utf8) else {
      throw ChoiceTraceBlobError.malformed("span label is not valid UTF-8")
    }
    return decoded
  }
}

extension ChoiceTraceBinaryDecoder {
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
