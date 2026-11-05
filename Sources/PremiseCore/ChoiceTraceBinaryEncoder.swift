import Foundation
struct ChoiceTraceBinaryEncoder {

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
      let bitCount = bitEntry.count
      if bitCount < 0 {
        throw ChoiceTraceBlobError.malformed("bit count must be non-negative")
      }
      data.append(ChoiceTraceEntryTag.bits.rawValue)
      try appendCount(bitEntry.count, label: "bit count")
      appendUInt64(bitEntry.value)

    case .integer(let value):
      data.append(ChoiceTraceEntryTag.integer.rawValue)
      appendUInt64(value)

    case .boolean(let value):
      data.append(ChoiceTraceEntryTag.boolean.rawValue)
      data.append(value ? 1 : 0)

    case .bytes(let bytes):
      data.append(ChoiceTraceEntryTag.bytes.rawValue)
      try appendCount(bytes.count, label: "byte count")
      data.append(contentsOf: bytes)
    }
  }

  private mutating func append(
    _ span: ChoiceTrace.Span,
    entryCount: Int
  ) throws {
    guard span.start >= 0, span.end >= span.start, span.end <= entryCount else {
      throw ChoiceTraceBlobError.malformed(
        "span bounds are outside trace entries"
      )
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
