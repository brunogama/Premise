public struct PremiseData: Sendable {
  public enum Status: Sendable, Codable, Equatable {
    case active
    case exhausted
    case interesting
  }

  private var provider: PrimitiveProviderState
  private var spanStarts: [SpanStart]

  public private(set) var trace: ChoiceTrace
  public private(set) var status: Status

  /// Observations accumulated during this run.
  public private(set) var statistics: RunStatistics

  public init<Provider: PrimitiveProvider>(provider: Provider) {
    self.provider = PrimitiveProviderState(provider)
    trace = ChoiceTrace()
    spanStarts = []
    status = .active
    statistics = RunStatistics()
  }

  // MARK: - Primitive draws

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
    guard count > 0 else { return [] }

    let value = provider.drawBytes(count: count)
    trace.append(.bytes(value))
    updateStatus()
    return value
  }

  // MARK: - Strategy draw shorthand

  /// Draws a value using the given strategy.
  ///
  /// This is a convenience wrapper equivalent to `try strategy.draw(&self)`.
  ///
  /// ```swift
  /// let n = try data.draw(.integers(in: 0...100))
  /// ```
  public mutating func draw<T: Sendable>(_ strategy: Strategy<T>) throws -> T {
    try strategy.draw(&self)
  }

  // MARK: - Spans

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

  // MARK: - Statistics

  /// Records a named observation.
  ///
  /// Notes are displayed alongside the counterexample when a property fails,
  /// helping diagnose the distribution of inputs that triggered the failure.
  ///
  /// ```swift
  /// data.note("length", value: array.count)
  /// ```
  public mutating func note(_ label: String, value: some CustomStringConvertible) {
    statistics.notes.append(RunNote(label: label, value: value.description))
  }

  /// Records an occurrence of a named event.
  ///
  /// Events are counted across runs and printed in the summary, giving a
  /// rough distribution of interesting cases encountered during testing.
  ///
  /// ```swift
  /// data.event(n.isMultiple(of: 2) ? "even" : "odd")
  /// ```
  public mutating func event(_ label: String) {
    statistics.events.append(label)
  }

  /// Provides a score hint for corpus-guided generation.
  ///
  /// Higher scores indicate more interesting inputs.  The engine uses this
  /// to steer subsequent generation toward inputs that maximize the score.
  /// When multiple `target` calls are made in a single run, the maximum
  /// score is retained.
  ///
  /// ```swift
  /// data.target(Double(string.count), label: "string length")
  /// ```
  public mutating func target(_ score: Double, label: String? = nil) {
    let updated: Double
    if let existing = statistics.targetScore {
      updated = max(existing, score)
    } else {
      updated = score
    }
    statistics.targetScore = updated
    if let label {
      statistics.notes.append(RunNote(label: label, value: String(score)))
    }
  }

  // MARK: - Private

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

private extension PremiseData {
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
    guard width > 1 else { return 1 }
    return UInt64.bitWidth - (width - 1).leadingZeroBitCount
  }
}

private struct SpanStart: Sendable {
  var label: String?
  var start: Int
}

// MARK: - PrimitiveProviderState (CoW type-erased box)

private struct PrimitiveProviderState: Sendable {
  private var box: PrimitiveProviderBoxBase

  init<Provider: PrimitiveProvider>(_ provider: Provider) {
    box = PrimitiveProviderBox(provider)
  }

  var isExhausted: Bool { box.isExhausted }

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

// swiftlint:disable unavailable_function
private class PrimitiveProviderBoxBase: @unchecked Sendable {
  var isExhausted: Bool { fatalError("abstract") }
  func drawBits(count: Int) -> UInt64 { fatalError("abstract") }
  func drawBytes(count: Int) -> [UInt8] { fatalError("abstract") }
  func copy() -> PrimitiveProviderBoxBase { fatalError("abstract") }
}
// swiftlint:enable unavailable_function

private final class PrimitiveProviderBox<Provider: PrimitiveProvider>:
  PrimitiveProviderBoxBase, @unchecked Sendable
{
  private var provider: Provider

  init(_ provider: Provider) { self.provider = provider }

  override var isExhausted: Bool { provider.isExhausted }
  override func drawBits(count: Int) -> UInt64 { provider.drawBits(count: count) }
  override func drawBytes(count: Int) -> [UInt8] { provider.drawBytes(count: count) }
  override func copy() -> PrimitiveProviderBoxBase { PrimitiveProviderBox(provider) }
}
