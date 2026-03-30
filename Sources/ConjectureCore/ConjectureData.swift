public struct ConjectureData: Sendable {
  public enum Status: Sendable, Codable, Equatable {
    case active
    case exhausted
    case interesting
  }

  private var provider: PrimitiveProviderState
  private var spanStarts: [SpanStart]

  public private(set) var trace: ChoiceTrace
  public private(set) var status: Status

  public init<Provider: PrimitiveProvider>(provider: Provider) {
    self.provider = PrimitiveProviderState(provider)
    trace = ChoiceTrace()
    spanStarts = []
    status = .active
  }

  public mutating func drawInteger(in range: ClosedRange<Int>) -> Int {
    let raw = drawRawValue(bitCount: requiredBitCount(for: range))
    trace.append(.integer(raw))
    updateStatus()

    if range.lowerBound == range.upperBound {
      return range.lowerBound
    }
    if range.lowerBound == Int.min, range.upperBound == Int.max {
      return Int(bitPattern: UInt(truncatingIfNeeded: raw))
    }

    let lower = range.lowerBound
    let upper = range.upperBound
    let width = UInt64(upper - lower)
    return lower + Int(raw % (width + 1))
  }

  public mutating func drawInteger(in range: ClosedRange<UInt64>) -> UInt64 {
    let raw = drawRawValue(bitCount: requiredBitCount(for: range))
    trace.append(.integer(raw))
    updateStatus()

    if range.lowerBound == range.upperBound {
      return range.lowerBound
    }

    if range.lowerBound == 0, range.upperBound == .max {
      return raw
    }

    let width = range.upperBound - range.lowerBound
    return range.lowerBound + (raw % (width + 1))
  }

  public mutating func drawBoolean() -> Bool {
    let value = drawRawValue(bitCount: 1) & 1 == 1
    trace.append(.boolean(value))
    updateStatus()
    return value
  }

  public mutating func drawBytes(count: Int) -> [UInt8] {
    guard count > 0 else {
      return []
    }

    let value = provider.drawBytes(count: count)
    trace.append(.bytes(value))
    updateStatus()
    return value
  }

  public mutating func withSpan<T>(
    _ label: String? = nil,
    _ body: (inout Self) throws -> T
  ) rethrows -> T {
    spanStarts.append(SpanStart(label: label, start: trace.entries.count))
    defer {
      let spanStart = spanStarts.removeLast()
      trace.append(
        span: ChoiceTrace.Span(
          label: spanStart.label,
          start: spanStart.start,
          end: trace.entries.count
        )
      )
    }
    return try body(&self)
  }

  public mutating func markInteresting() {
    status = .interesting
  }

  public mutating func snapshot() -> ChoiceTrace {
    trace
  }

  private mutating func drawRawValue(bitCount: Int) -> UInt64 {
    let value = provider.drawBits(count: bitCount)
    updateStatus()
    return value
  }

  private mutating func updateStatus() {
    if status == .active, provider.isExhausted {
      status = .exhausted
    }
  }
}

private extension ConjectureData {
  func requiredBitCount(for range: ClosedRange<Int>) -> Int {
    if range.lowerBound == Int.min, range.upperBound == Int.max {
      return UInt64.bitWidth
    }

    let width = UInt64(range.upperBound - range.lowerBound) + 1
    return bitCount(forWidth: width)
  }

  func requiredBitCount(for range: ClosedRange<UInt64>) -> Int {
    if range.lowerBound == 0, range.upperBound == .max {
      return UInt64.bitWidth
    }

    let width = range.upperBound - range.lowerBound + 1
    return bitCount(forWidth: width)
  }

  func bitCount(forWidth width: UInt64) -> Int {
    guard width > 1 else {
      return 1
    }

    return UInt64.bitWidth - (width - 1).leadingZeroBitCount
  }
}

private struct SpanStart: Sendable {
  var label: String?
  var start: Int
}

/// Stack-local copy-on-write wrapper around a concrete primitive provider.
private struct PrimitiveProviderState: Sendable {
  private var box: PrimitiveProviderBoxBase

  init<Provider: PrimitiveProvider>(_ provider: Provider) {
    box = PrimitiveProviderBox(provider)
  }

  var isExhausted: Bool {
    box.isExhausted
  }

  mutating func drawBits(count: Int) -> UInt64 {
    ensureUniqueBox()
    return box.drawBits(count: count)
  }

  mutating func drawBytes(count: Int) -> [UInt8] {
    ensureUniqueBox()
    return box.drawBytes(count: count)
  }

  private mutating func ensureUniqueBox() {
    if !isKnownUniquelyReferenced(&box) {
      box = box.copy()
    }
  }
}

private class PrimitiveProviderBoxBase: @unchecked Sendable {
  var isExhausted: Bool {
    assertionFailure("PrimitiveProviderBoxBase should not be used directly.")
    return false
  }

  func drawBits(count: Int) -> UInt64 {
    assertionFailure("PrimitiveProviderBoxBase should not be used directly.")
    return 0
  }

  func drawBytes(count: Int) -> [UInt8] {
    assertionFailure("PrimitiveProviderBoxBase should not be used directly.")
    return []
  }

  func copy() -> PrimitiveProviderBoxBase {
    assertionFailure("PrimitiveProviderBoxBase should not be used directly.")
    return PrimitiveProviderBoxBase()
  }
}

private final class PrimitiveProviderBox<Provider: PrimitiveProvider>:
  PrimitiveProviderBoxBase, @unchecked Sendable
{
  private var provider: Provider

  init(_ provider: Provider) {
    self.provider = provider
  }

  override var isExhausted: Bool {
    provider.isExhausted
  }

  override func drawBits(count: Int) -> UInt64 {
    provider.drawBits(count: count)
  }

  override func drawBytes(count: Int) -> [UInt8] {
    provider.drawBytes(count: count)
  }

  override func copy() -> PrimitiveProviderBoxBase {
    PrimitiveProviderBox(provider)
  }
}
