import PremiseCore

// swiftlint:disable:next function_parameter_count - Failure, machine, configuration, and run metadata have separate owners.
func shrinkFailure<State: Sendable>(
  _ failure: StateMachineFailure,
  machine: RuleBasedStateMachine<State>,
  config: StateMachineConfig,
  metadata: StateMachineRunMetadata
) async -> StateMachineFailure {
  var shrinker = StateMachineShrinker(
    original: failure,
    best: failure,
    machine: machine,
    config: config,
    metadata: metadata
  )
  return await shrinker.run()
}

private struct StateMachineShrinker<State: Sendable> {
  let original: StateMachineFailure
  var best: StateMachineFailure
  let machine: RuleBasedStateMachine<State>
  let config: StateMachineConfig
  let metadata: StateMachineRunMetadata
  var iterations = 0

  mutating func run() async -> StateMachineFailure {
    while iterations < config.maxShrinkIterations {
      if await shrinkSpan() { continue }
      if !(await shrinkInteger()) { break }
    }
    return best.with(
      replayTrace: best.replayTrace,
      program: best.program,
      shrinkCount: iterations
    )
  }

  private mutating func shrinkSpan() async -> Bool {
    for span in best.replayTrace.spans.reversed()
    where await tryTrace(removing(span: span, from: best.replayTrace)) {
      return true
    }
    return false
  }

  private mutating func shrinkInteger() async -> Bool {
    for index in best.replayTrace.entries.indices {
      guard
        case .integer(let value) = best.replayTrace.entries[index], value > 0
      else { continue }
      if await shrinkInteger(at: index, value: value) { return true }
    }
    return false
  }

  private mutating func shrinkInteger(
    at index: Int,
    value: UInt64
  ) async -> Bool {
    for candidateValue in [UInt64(0), value / 2, value - 1] {
      var candidate = best.replayTrace
      candidate.entries[index] = .integer(candidateValue)
      if await tryTrace(candidate) { return true }
    }
    return false
  }

  private mutating func tryTrace(_ candidate: ChoiceTrace) async -> Bool {
    do {
      try await runOnce(
        machine,
        config: config,
        provider: ReplayProvider(trace: candidate),
        metadata: metadata
      )
      return false
    } catch let failure as StateMachineFailure {
      return accept(failure, trace: candidate)
    } catch {
      return false
    }
  }

  private mutating func accept(
    _ failure: StateMachineFailure,
    trace: ChoiceTrace
  ) -> Bool {
    guard failure.matches(original) else { return false }
    iterations += 1
    best = failure.with(
      replayTrace: trace,
      program: failure.program,
      shrinkCount: iterations
    )
    return true
  }
}

private extension StateMachineFailure {
  func matches(_ original: StateMachineFailure) -> Bool {
    phase == original.phase
      && ruleName == original.ruleName
      && invariantName == original.invariantName
      && underlyingDescription == original.underlyingDescription
  }
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
      label: span.label,
      start: span.start - (removed.end - removed.start),
      end: span.end - (removed.end - removed.start)
    )
  }
  return nil
}
