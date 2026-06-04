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
    // Replay stored failures first.
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
            discovery: .knownFailure
          )
          return .failure(minimized.record, value: minimized.value)
        }
      }
    }

    // Use a random seed when none is specified so each invocation
    // independently explores the input space.  The seed is stored in
    // the FailureRecord so failures are always reproducible.
    let baseSeed = config.seed ?? UInt64.random(in: .min ... .max)

    // Deadline for wall-clock timeout.
    let deadline: Date?
    if let timeout = config.timeoutSeconds {
      deadline = Date(timeIntervalSinceNow: timeout)
    } else {
      deadline = nil
    }

    for index in 0..<config.maxRuns {
      // Check deadline before each run.
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
          seed: baseSeed
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
          seed: baseSeed
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
          discovery: discovery
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
          discovery: discovery
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
        discovery: discovery
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
          discovery: discovery
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
          discovery: discovery
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
        discovery: discovery
      ),
      value: initialValue
    )
  }

  // MARK: - Internal execution helpers

  /// Executes a single run from a stored trace.
  func executeSingle(
    trace: ChoiceTrace,
    property: @Sendable (Value) throws -> Void
  ) -> ExecutionFailure<Value>? {
    let provider = ReplayProvider(trace: trace)
    return executeSingle(provider: provider, property: property)
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
    var data = PremiseData(provider: provider)

    // Draw phase — any error here means the strategy couldn't produce a
    // valid input (e.g. filter exhausted).  Skip the run silently.
    let drawnValue: Value
    do {
      drawnValue = try strategy.draw(&data)
    } catch {
      return nil
    }

    // Property phase — errors here are genuine failures.
    do {
      try property(drawnValue)
      return nil
    } catch {
      let record = FailureRecord(
        propertyID: propertyID,
        trace: data.snapshot(),
        errorMessage: String(describing: error),
        runCount: 1,
        shrinkCount: 0
      )
      return ExecutionFailure(record: record, value: drawnValue)
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
        shrinkCount: 0
      )
      return ExecutionFailure(record: record, value: drawnValue)
    }
  }
}

// MARK: - ExecutionFailure

struct ExecutionFailure<Value: Sendable> {
  let record: FailureRecord
  let value: Value
}
