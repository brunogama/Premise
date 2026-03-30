public struct ReplayProvider: PrimitiveProvider {
  private let trace: ChoiceTrace
  private var index: Int
  private var exhausted: Bool

  public init(trace: ChoiceTrace) {
    self.trace = trace
    index = 0
    exhausted = false
  }

  public mutating func drawBits(count: Int) -> UInt64 {
    guard count > 0 else { return 0 }
    guard index < trace.entries.count else {
      markExhausted()
      return 0
    }
    defer { index += 1 }
    switch trace.entries[index] {
    case .bits(let entry):
      guard entry.count == count else {
        markExhausted()
        return 0
      }
      return entry.value

    case .integer(let value):
      return count >= 64 ? value : value & ((1 << count) - 1)

    case .boolean(let value):
      return value ? 1 : 0

    case .bytes(let bytes):
      guard let first = bytes.first else { return 0 }
      return UInt64(first)
    }
  }

  public mutating func drawBytes(count: Int) -> [UInt8] {
    guard count > 0 else { return [] }
    guard index < trace.entries.count else {
      markExhausted()
      return []
    }
    defer { index += 1 }
    switch trace.entries[index] {
    case .bytes(let bytes):
      return bytes

    case .bits:
      markExhausted()
      return []

    case .integer(let value):
      return (0..<count).map { shift in
        UInt8(truncatingIfNeeded: value >> UInt64(shift * 8))
      }

    case .boolean(let value):
      return [value ? 1 : 0]
    }
  }

  public mutating func markExhausted() {
    exhausted = true
  }

  public var isExhausted: Bool {
    exhausted
  }
}
