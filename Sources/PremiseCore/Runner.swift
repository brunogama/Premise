import Foundation

public struct Runner<Value: Sendable>: Sendable {
  public let strategy: Strategy<Value>
  public let config: PropertyConfig
  public let propertyID: PropertyIdentity

  public init(
    strategy: Strategy<Value>,
    config: PropertyConfig = .default,
    propertyID: PropertyIdentity = PropertyIdentity(
      fileID: "unknown",
      line: 0,
      strategyLabel: "unknown"
    )
  ) {
    self.strategy = strategy
    self.config = config
    self.propertyID = propertyID
  }

  // MARK: - Public run

  public func runDetailed(
    explicitExamples: [Value] = [],
    _ property: @escaping @Sendable (Value, inout PremiseData) throws -> Void,
    replayTraces: [ChoiceTrace] = []
  ) async -> DetailedRunResult<Value> {
    var report = RunReport()

    for phase in config.phases {
      switch phase {
      case .explicit:
        for example in explicitExamples {
          if let failure = executeExplicit(
            example,
            property: property,
            report: &report
          ) {
            report.applyHealthChecks(
              enabledChecks: config.healthChecks,
              maxRuns: config.maxRuns
            )
            return .failure(failure.record, value: failure.value, report: report)
          }
        }

      case .replay:
        guard config.replayEnabled else { continue }
        for trace in replayTraces {
          switch executeAttempt(trace: trace, property: property) {
          case .passed(let statistics):
            report.recordPhase(.replay)
            report.merge(statistics)

          case .rejected:
            report.recordRejected()

          case .failure(let failure):
            let minimized = minimizeIfNeeded(
              failure: failure,
              runCount: 1,
              property: property,
              seed: failure.record.seed,
              discovery: .knownFailure
            )
            report.recordPhase(.replay)
            report.merge(minimized.record.statistics)
            report.applyHealthChecks(
              enabledChecks: config.healthChecks,
              maxRuns: config.maxRuns
            )
            return .failure(minimized.record, value: minimized.value, report: report)
          }
        }

      case .generate:
        let baseSeed = config.seed ?? UInt64.random(in: .min ... .max)
        let deadline = config.timeoutSeconds.map { Date(timeIntervalSinceNow: $0) }

        for index in 0..<config.maxRuns {
          if let deadline, Date() > deadline {
            break
          }

          let provider = PseudoRandomProvider(
            seed: baseSeed &+ UInt64(index),
            maxDraws: config.maxDrawsPerRun
          )

          switch executeAttempt(provider: provider, property: property) {
          case .passed(let statistics):
            report.recordPhase(.generate)
            report.merge(statistics)

          case .rejected:
            report.recordRejected()

          case .failure(let failure):
            let minimized = minimizeIfNeeded(
              failure: failure,
              runCount: index + 1,
              property: property,
              seed: baseSeed,
              discovery: .newFailure
            )
            report.recordPhase(.generate)
            report.merge(minimized.record.statistics)
            report.applyHealthChecks(
              enabledChecks: config.healthChecks,
              maxRuns: config.maxRuns
            )
            return .failure(minimized.record, value: minimized.value, report: report)
          }
        }

      case .shrink:
        continue
      }
    }

    report.applyHealthChecks(
      enabledChecks: config.healthChecks,
      maxRuns: config.maxRuns
    )
    return .passed(report)
  }

  public func runDetailed(
    explicitExamples: [Value] = [],
    _ property: @escaping @Sendable (Value) throws -> Void,
    replayTraces: [ChoiceTrace] = []
  ) async -> DetailedRunResult<Value> {
    await runDetailed(explicitExamples: explicitExamples, { value, _ in
      try property(value)
    }, replayTraces: replayTraces)
  }

  /// Executes the property, replaying any stored traces first, then running
  /// fresh generations.  The first failure found is minimised via
  /// ``ShrinkMachine`` before being returned.
  ///
  /// When `config.seed` is `nil` a cryptographically-random base seed is
  /// chosen for this invocation and embedded in the returned ``FailureRecord``
  /// so the exact run can be reproduced:
  ///
  /// ```swift
  /// // Reproduce a failure:
  /// let config = PropertyConfig(seed: record.seed)
  /// ```
  public func run(
    _ property: @escaping @Sendable (Value) throws -> Void,
    replayTraces: [ChoiceTrace] = []
  ) async -> RunResult<Value> {
    if config.replayEnabled {
      for trace in replayTraces {
        if let failure = executeSingle(trace: trace, property: property) {
          let minimized = minimizeTrace(
            initialTrace: failure.record.trace,
            errorMessage: failure.record.errorMessage,
            initialValue: failure.value,
            runCount: 1,
            property: property,
            seed: failure.record.seed,
            statistics: failure.record.statistics,
            discovery: .knownFailure
          )
          return .failure(minimized.record, value: minimized.value)
        }
      }
    }

    let baseSeed = config.seed ?? UInt64.random(in: .min ... .max)

    let deadline: Date?
    if let timeout = config.timeoutSeconds {
      deadline = Date(timeIntervalSinceNow: timeout)
    } else {
      deadline = nil
    }

    for index in 0..<config.maxRuns {
      if let deadline, Date() > deadline {
        return .passed(runs: index)
      }

      let providerSeed = baseSeed &+ UInt64(index)
      let provider = PseudoRandomProvider(seed: providerSeed, maxDraws: config.maxDrawsPerRun)
      if let failure = executeSingle(provider: provider, property: property) {
        let minimized = minimizeTrace(
          initialTrace: failure.record.trace,
          errorMessage: failure.record.errorMessage,
          initialValue: failure.value,
          runCount: index + 1,
          property: property,
          seed: baseSeed,
          statistics: failure.record.statistics
        )
        return .failure(minimized.record, value: minimized.value)
      }
    }

    return .passed(runs: config.maxRuns)
  }

  /// Executes an async property, replaying stored traces first, then running
  /// fresh generations. This overload mirrors the synchronous runner while
  /// allowing property bodies to await application code directly.
  public func run(
    _ property: @escaping @Sendable (Value) async throws -> Void,
    replayTraces: [ChoiceTrace] = []
  ) async -> RunResult<Value> {
    if config.replayEnabled {
      for trace in replayTraces {
        if let failure = await executeSingleAsync(trace: trace, property: property) {
          let minimized = await minimizeTrace(
            initialTrace: failure.record.trace,
            errorMessage: failure.record.errorMessage,
            initialValue: failure.value,
            runCount: 1,
            property: property,
            seed: failure.record.seed,
            statistics: failure.record.statistics,
            discovery: .knownFailure
          )
          return .failure(minimized.record, value: minimized.value)
        }
      }
    }

    let baseSeed = config.seed ?? UInt64.random(in: .min ... .max)

    let deadline: Date?
    if let timeout = config.timeoutSeconds {
      deadline = Date(timeIntervalSinceNow: timeout)
    } else {
      deadline = nil
    }

    for index in 0..<config.maxRuns {
      if let deadline, Date() > deadline {
        return .passed(runs: index)
      }

      let providerSeed = baseSeed &+ UInt64(index)
      let provider = PseudoRandomProvider(seed: providerSeed, maxDraws: config.maxDrawsPerRun)
      if let failure = await executeSingleAsync(provider: provider, property: property) {
        let minimized = await minimizeTrace(
          initialTrace: failure.record.trace,
          errorMessage: failure.record.errorMessage,
          initialValue: failure.value,
          runCount: index + 1,
          property: property,
          seed: baseSeed,
          statistics: failure.record.statistics
        )
        return .failure(minimized.record, value: minimized.value)
      }
    }

    return .passed(runs: config.maxRuns)
  }

  // MARK: - Replay

  /// Returns `true` if replaying `trace` against `property` still fails.
  public func replay(
    _ trace: ChoiceTrace,
    property: @Sendable (Value) throws -> Void
  ) -> Bool {
    executeSingle(trace: trace, property: property) != nil
  }

  /// Returns `true` if replaying `trace` against a data-aware property still fails.
  public func replay(
    _ trace: ChoiceTrace,
    property: @Sendable (Value, inout PremiseData) throws -> Void
  ) -> Bool {
    executeSingle(trace: trace, property: property) != nil
  }

  /// Returns `true` if replaying `trace` against an async property still fails.
  public func replay(
    _ trace: ChoiceTrace,
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> Bool {
    await executeSingleAsync(trace: trace, property: property) != nil
  }

  // MARK: - Minimisation (public — also used by ParallelRunner)

  /// Runs ``ShrinkMachine`` on `initialTrace` and returns the smallest
  /// failing counterexample together with an updated ``FailureRecord``.
  public func minimizeTrace(
    initialTrace: ChoiceTrace,
    errorMessage: String,
    initialValue: Value,
    runCount: Int,
    property: @escaping @Sendable (Value) throws -> Void,
    seed: UInt64?,
    statistics: RunStatistics = RunStatistics(),
    discovery: FailureDiscovery = .newFailure
  ) -> (record: FailureRecord, value: Value) {
    guard config.maxShrinkIterations > 0 else {
      return (
        record: FailureRecord(
          propertyID: propertyID,
          trace: initialTrace,
          errorMessage: errorMessage,
          runCount: runCount,
          shrinkCount: 0,
          seed: seed,
          discovery: discovery,
          statistics: statistics
        ),
        value: initialValue
      )
    }

    var machine = ShrinkMachine(
      runner: self,
      property: property,
      bestTrace: initialTrace,
      maxIterations: config.maxShrinkIterations
    )
    let shrunkTrace = machine.run()

    // Re-execute with the shrunk trace to extract the minimised value.
    if let rerun = executeSingle(trace: shrunkTrace, property: property) {
      return (
        record: FailureRecord(
          propertyID: propertyID,
          trace: shrunkTrace,
          errorMessage: rerun.record.errorMessage,
          runCount: runCount,
          shrinkCount: machine.iterations,
          seed: seed,
          discovery: discovery,
          statistics: rerun.record.statistics
        ),
        value: rerun.value
      )
    }

    // Shrunk trace no longer fails — return original with updated counts.
    return (
      record: FailureRecord(
        propertyID: propertyID,
        trace: initialTrace,
        errorMessage: errorMessage,
        runCount: runCount,
        shrinkCount: machine.iterations,
        seed: seed,
        discovery: discovery,
        statistics: statistics
      ),
      value: initialValue
    )
  }

  /// Runs trace-level shrinking for a data-aware property.
  public func minimizeTrace(
    initialTrace: ChoiceTrace,
    errorMessage: String,
    initialValue: Value,
    runCount: Int,
    property: @escaping @Sendable (Value, inout PremiseData) throws -> Void,
    seed: UInt64?,
    statistics: RunStatistics = RunStatistics(),
    discovery: FailureDiscovery = .newFailure
  ) -> (record: FailureRecord, value: Value) {
    guard config.maxShrinkIterations > 0 else {
      return (
        record: FailureRecord(
          propertyID: propertyID,
          trace: initialTrace,
          errorMessage: errorMessage,
          runCount: runCount,
          shrinkCount: 0,
          seed: seed,
          discovery: discovery,
          statistics: statistics
        ),
        value: initialValue
      )
    }

    let shrink = minimizeDataAwareTrace(
      initialTrace: initialTrace,
      maxIterations: config.maxShrinkIterations,
      property: property
    )

    if let rerun = executeSingle(trace: shrink.trace, property: property) {
      return (
        record: FailureRecord(
          propertyID: propertyID,
          trace: shrink.trace,
          errorMessage: rerun.record.errorMessage,
          runCount: runCount,
          shrinkCount: shrink.iterations,
          seed: seed,
          discovery: discovery,
          statistics: rerun.record.statistics
        ),
        value: rerun.value
      )
    }

    return (
      record: FailureRecord(
        propertyID: propertyID,
        trace: initialTrace,
        errorMessage: errorMessage,
        runCount: runCount,
        shrinkCount: shrink.iterations,
        seed: seed,
        discovery: discovery,
        statistics: statistics
      ),
      value: initialValue
    )
  }

  /// Async variant of ``minimizeTrace`` used by async property overloads.
  public func minimizeTrace(
    initialTrace: ChoiceTrace,
    errorMessage: String,
    initialValue: Value,
    runCount: Int,
    property: @escaping @Sendable (Value) async throws -> Void,
    seed: UInt64?,
    statistics: RunStatistics = RunStatistics(),
    discovery: FailureDiscovery = .newFailure
  ) async -> (record: FailureRecord, value: Value) {
    guard config.maxShrinkIterations > 0 else {
      return (
        record: FailureRecord(
          propertyID: propertyID,
          trace: initialTrace,
          errorMessage: errorMessage,
          runCount: runCount,
          shrinkCount: 0,
          seed: seed,
          discovery: discovery,
          statistics: statistics
        ),
        value: initialValue
      )
    }

    var machine = AsyncShrinkMachine(
      runner: self,
      property: property,
      bestTrace: initialTrace,
      maxIterations: config.maxShrinkIterations
    )
    let shrunkTrace = await machine.run()

    if let rerun = await executeSingleAsync(trace: shrunkTrace, property: property) {
      return (
        record: FailureRecord(
          propertyID: propertyID,
          trace: shrunkTrace,
          errorMessage: rerun.record.errorMessage,
          runCount: runCount,
          shrinkCount: machine.iterations,
          seed: seed,
          discovery: discovery,
          statistics: rerun.record.statistics
        ),
        value: rerun.value
      )
    }

    return (
      record: FailureRecord(
        propertyID: propertyID,
        trace: initialTrace,
        errorMessage: errorMessage,
        runCount: runCount,
        shrinkCount: machine.iterations,
        seed: seed,
        discovery: discovery,
        statistics: statistics
      ),
      value: initialValue
    )
  }

  // MARK: - Internal execution helpers

  private func minimizeDataAwareTrace(
    initialTrace: ChoiceTrace,
    maxIterations: Int,
    property: @escaping @Sendable (Value, inout PremiseData) throws -> Void
  ) -> (trace: ChoiceTrace, iterations: Int) {
    var bestTrace = initialTrace
    var iterations = 0

    func integerCandidates(for value: UInt64) -> [UInt64] {
      var candidates: [UInt64] = [0]
      if value > 1 {
        candidates.append(value / 2)
      }
      if value > 0 {
        candidates.append(value - 1)
      }
      return Array(Set(candidates)).sorted()
    }

    func adjust(
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

    func removing(span: ChoiceTrace.Span, from trace: ChoiceTrace) -> ChoiceTrace {
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

    func tryTrace(_ candidate: ChoiceTrace) -> Bool {
      if replay(candidate, property: property) {
        bestTrace = candidate
        iterations += 1
        return true
      }
      return false
    }

    func deletionPass() -> Bool {
      guard !bestTrace.spans.isEmpty else { return false }
      for index in bestTrace.spans.indices.reversed() {
        let span = bestTrace.spans[index]
        if tryTrace(removing(span: span, from: bestTrace)) {
          return true
        }
      }
      return false
    }

    func integerPass() -> Bool {
      for index in bestTrace.entries.indices {
        guard case .integer(let value) = bestTrace.entries[index] else {
          continue
        }
        for candidateValue in integerCandidates(for: value) {
          var candidate = bestTrace
          candidate.entries[index] = .integer(candidateValue)
          if tryTrace(candidate) {
            return true
          }
        }
      }
      return false
    }

    func collectionPass() -> Bool {
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

    while iterations < maxIterations {
      let improved = deletionPass() || integerPass() || collectionPass()
      if !improved {
        break
      }
    }

    return (bestTrace, iterations)
  }

  private func executeExplicit(
    _ value: Value,
    property: @Sendable (Value, inout PremiseData) throws -> Void,
    report: inout RunReport
  ) -> ExecutionFailure<Value>? {
    var data = PremiseData(
      provider: PseudoRandomProvider(seed: 0, maxDraws: config.maxDrawsPerRun)
    )
    report.recordPhase(.explicit)

    do {
      try property(value, &data)
      report.merge(data.statistics)
      return nil
    } catch {
      let record = FailureRecord(
        propertyID: propertyID,
        trace: data.snapshot(),
        errorMessage: String(describing: error),
        runCount: 0,
        shrinkCount: 0,
        statistics: data.statistics
      )
      report.merge(data.statistics)
      return ExecutionFailure(record: record, value: value)
    }
  }

  private func minimizeIfNeeded(
    failure: ExecutionFailure<Value>,
    runCount: Int,
    property: @escaping @Sendable (Value, inout PremiseData) throws -> Void,
    seed: UInt64?,
    discovery: FailureDiscovery
  ) -> (record: FailureRecord, value: Value) {
    guard config.phases.includes(.shrink) else {
      var record = failure.record
      record.runCount = runCount
      record.seed = seed
      record.discovery = discovery
      return (record, failure.value)
    }

    return minimizeTrace(
      initialTrace: failure.record.trace,
      errorMessage: failure.record.errorMessage,
      initialValue: failure.value,
      runCount: runCount,
      property: property,
      seed: seed,
      statistics: failure.record.statistics,
      discovery: discovery
    )
  }

  private func executeAttempt(
    trace: ChoiceTrace,
    property: @Sendable (Value, inout PremiseData) throws -> Void
  ) -> ExecutionAttempt<Value> {
    let provider = ReplayProvider(trace: trace)
    return executeAttempt(provider: provider, property: property)
  }

  private func executeAttempt(
    provider: some PrimitiveProvider,
    property: @Sendable (Value, inout PremiseData) throws -> Void
  ) -> ExecutionAttempt<Value> {
    var data = PremiseData(provider: provider)

    let drawnValue: Value
    do {
      drawnValue = try strategy.draw(&data)
    } catch {
      return .rejected
    }

    do {
      try property(drawnValue, &data)
      return .passed(data.statistics)
    } catch {
      let record = FailureRecord(
        propertyID: propertyID,
        trace: data.snapshot(),
        errorMessage: String(describing: error),
        runCount: 1,
        shrinkCount: 0,
        statistics: data.statistics
      )
      return .failure(ExecutionFailure(record: record, value: drawnValue))
    }
  }

  /// Executes a single run from a stored trace.
  func executeSingle(
    trace: ChoiceTrace,
    property: @Sendable (Value, inout PremiseData) throws -> Void
  ) -> ExecutionFailure<Value>? {
    let provider = ReplayProvider(trace: trace)
    return executeSingle(provider: provider, property: property)
  }

  /// Executes a single run from a stored trace.
  func executeSingle(
    trace: ChoiceTrace,
    property: @Sendable (Value) throws -> Void
  ) -> ExecutionFailure<Value>? {
    executeSingle(trace: trace) { value, _ in
      try property(value)
    }
  }

  /// Executes a single run from a provider, returning a failure or nil.
  func executeSingle(
    provider: some PrimitiveProvider,
    property: @Sendable (Value, inout PremiseData) throws -> Void
  ) -> ExecutionFailure<Value>? {
    if case .failure(let failure) = executeAttempt(provider: provider, property: property) {
      return failure
    }
    return nil
  }

  /// Executes a single run from a provider, returning a failure or nil.
  ///
  /// Draw-phase errors (including ``StrategyError``) are treated as
  /// "invalid input — skip this run" and return nil.  Only property-phase
  /// errors are reported as failures.
  func executeSingle(
    provider: some PrimitiveProvider,
    property: @Sendable (Value) throws -> Void
  ) -> ExecutionFailure<Value>? {
    executeSingle(provider: provider) { value, _ in
      try property(value)
    }
  }

  /// Executes a single async run from a stored trace.
  func executeSingleAsync(
    trace: ChoiceTrace,
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> ExecutionFailure<Value>? {
    let provider = ReplayProvider(trace: trace)
    return await executeSingleAsync(provider: provider, property: property)
  }

  /// Executes a single async run from a provider, returning a failure or nil.
  func executeSingleAsync(
    provider: some PrimitiveProvider,
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> ExecutionFailure<Value>? {
    var data = PremiseData(provider: provider)

    let drawnValue: Value
    do {
      drawnValue = try strategy.draw(&data)
    } catch {
      return nil
    }

    do {
      try await property(drawnValue)
      return nil
    } catch {
      let record = FailureRecord(
        propertyID: propertyID,
        trace: data.snapshot(),
        errorMessage: String(describing: error),
        runCount: 1,
        shrinkCount: 0,
        statistics: data.statistics
      )
      return ExecutionFailure(record: record, value: drawnValue)
    }
  }
}

// MARK: - ExecutionAttempt

private enum ExecutionAttempt<Value: Sendable> {
  case passed(RunStatistics)
  case rejected
  case failure(ExecutionFailure<Value>)
}

// MARK: - ExecutionFailure

struct ExecutionFailure<Value: Sendable> {
  let record: FailureRecord
  let value: Value
}
