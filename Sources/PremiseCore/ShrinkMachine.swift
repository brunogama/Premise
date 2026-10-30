/// Shrinks a failing choice trace by replaying smaller candidates.
public struct ShrinkMachine<Value: Sendable> {
  /// Runner used to replay candidate traces.
  public let runner: Runner<Value>
  /// Property replayed for each candidate.
  public let property: @Sendable (Value) throws -> Void
  /// Smallest failing trace found so far.
  public private(set) var bestTrace: ChoiceTrace
  /// Number of successful shrinking steps.
  public private(set) var iterations: Int
  /// Maximum number of successful shrinking steps.
  public let maxIterations: Int

  /// Creates a shrinking machine for the supplied failing trace.
  public init(
    runner: Runner<Value>,
    property: @escaping @Sendable (Value) throws -> Void,
    bestTrace: ChoiceTrace,
    maxIterations: Int
  ) {
    self.runner = runner
    self.property = property
    self.bestTrace = bestTrace
    self.maxIterations = maxIterations
    iterations = 0
  }

  /// Runs the shrinking passes and returns the best failing trace.
  public mutating func run() -> ChoiceTrace {
    while iterations < maxIterations {
      let improved = deletionPass() || integerPass() || collectionPass()
      if !improved {
        break
      }
    }
    return bestTrace
  }

  /// Attempts to delete spans while preserving the failure.
  public mutating func deletionPass() -> Bool {
    guard !bestTrace.spans.isEmpty else { return false }
    for index in bestTrace.spans.indices.reversed() {
      let span = bestTrace.spans[index]
      let candidate = removing(span: span, from: bestTrace)
      if tryTrace(candidate) {
        return true
      }
    }
    return false
  }

  /// Attempts to reduce integer choices while preserving the failure.
  public mutating func integerPass() -> Bool {
    for index in bestTrace.entries.indices {
      guard case .integer(let value) = bestTrace.entries[index] else {
        continue
      }
      let candidates = integerCandidates(for: value)
      for candidateValue in candidates {
        var candidate = bestTrace
        candidate.entries[index] = .integer(candidateValue)
        if tryTrace(candidate) {
          return true
        }
      }
    }
    return false
  }

  /// Attempts to remove collection elements while preserving the failure.
  public mutating func collectionPass() -> Bool {
    guard !bestTrace.spans.isEmpty else { return false }
    for index in bestTrace.spans.indices.reversed() {
      let span = bestTrace.spans[index]
      guard span.start > 0,
        case .integer(let count) = bestTrace.entries[span.start - 1],
        count > 0
      else {
        continue
      }
      var candidate = removing(span: span, from: bestTrace)
      candidate.entries[span.start - 1] = .integer(count - 1)
      if tryTrace(candidate) {
        return true
      }
    }
    return false
  }

  /// Replays a candidate and retains it if the property still fails.
  public mutating func tryTrace(_ candidate: ChoiceTrace) -> Bool {
    if runner.replay(candidate, property: property) {
      bestTrace = candidate
      iterations += 1
      return true
    }
    return false
  }

  private func integerCandidates(for value: UInt64) -> [UInt64] {
    var candidates: [UInt64] = [0]
    if value > 1 {
      candidates.append(value / 2)
    }
    if value > 0 {
      candidates.append(value - 1)
    }
    return Array(Set(candidates)).sorted()
  }

  private func removing(
    span: ChoiceTrace.Span,
    from trace: ChoiceTrace
  ) -> ChoiceTrace {
    var candidate = trace
    guard span.start < span.end, span.end <= candidate.entries.count else {
      return candidate
    }
    candidate.entries.removeSubrange(span.start..<span.end)
    candidate.spans = candidate.spans.compactMap { existing in
      adjust(span: existing, removed: span)
    }
    return candidate
  }

  private func adjust(
    span: ChoiceTrace.Span,
    removed: ChoiceTrace.Span
  ) -> ChoiceTrace.Span? {
    if span.end <= removed.start {
      return span
    }
    if span.start >= removed.end {
      return ChoiceTrace.Span(
        start: span.start - (removed.end - removed.start),
        end: span.end - (removed.end - removed.start)
      )
    }
    return nil
  }
}
