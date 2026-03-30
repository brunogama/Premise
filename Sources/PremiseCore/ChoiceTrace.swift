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
