struct DataAwareTraceShrinker<Value: Sendable> {
  let runner: Runner<Value>
  let property: @Sendable (Value, inout PremiseData) throws -> Void
  let maxIterations: Int
  var bestTrace: ChoiceTrace
  var iterations = 0

  mutating func run() -> (trace: ChoiceTrace, iterations: Int) {
    while iterations < maxIterations {
      let improved = deletionPass() || integerPass() || collectionPass()
      if !improved { break }
    }
    return (bestTrace, iterations)
  }

  private func integerCandidates(for value: UInt64) -> [UInt64] {
    var candidates: [UInt64] = [0]
    if value > 1 { candidates.append(value / 2) }
    if value > 0 { candidates.append(value - 1) }
    return Array(Set(candidates)).sorted()
  }

  private func adjust(
    span: ChoiceTrace.Span,
    removed: ChoiceTrace.Span
  ) -> ChoiceTrace.Span? {
    if span.end <= removed.start { return span }
    if span.start >= removed.end {
      return ChoiceTrace.Span(
        start: span.start - (removed.end - removed.start),
        end: span.end - (removed.end - removed.start)
      )
    }
    return nil
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

  private mutating func tryTrace(_ candidate: ChoiceTrace) -> Bool {
    if runner.replay(candidate, property: property) {
      bestTrace = candidate
      iterations += 1
      return true
    }
    return false
  }

  private mutating func deletionPass() -> Bool {
    guard !bestTrace.spans.isEmpty else { return false }
    for index in bestTrace.spans.indices.reversed() {
      let span = bestTrace.spans[index]
      if tryTrace(removing(span: span, from: bestTrace)) { return true }
    }
    return false
  }

  private mutating func integerPass() -> Bool {
    for index in bestTrace.entries.indices {
      guard case .integer(let value) = bestTrace.entries[index] else {
        continue
      }
      for candidateValue in integerCandidates(for: value) {
        var candidate = bestTrace
        candidate.entries[index] = .integer(candidateValue)
        if tryTrace(candidate) { return true }
      }
    }
    return false
  }

  private mutating func collectionPass() -> Bool {
    guard !bestTrace.spans.isEmpty else { return false }
    for index in bestTrace.spans.indices.reversed() {
      let span = bestTrace.spans[index]
      guard span.start > 0,
        case .integer(let count) = bestTrace.entries[span.start - 1],
        count > 0
      else { continue }
      var candidate = removing(span: span, from: bestTrace)
      candidate.entries[span.start - 1] = .integer(count - 1)
      if tryTrace(candidate) { return true }
    }
    return false
  }
}
