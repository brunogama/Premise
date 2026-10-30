extension Runner {
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
    let context = ShrinkContext(
      trace: initialTrace,
      errorMessage: errorMessage,
      value: initialValue,
      runCount: runCount,
      seed: seed,
      statistics: statistics,
      discovery: discovery
    )
    let session = ShrinkSession(runner: self, context: context)
    return session.minimize(property: property)
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
    let context = ShrinkContext(
      trace: initialTrace,
      errorMessage: errorMessage,
      value: initialValue,
      runCount: runCount,
      seed: seed,
      statistics: statistics,
      discovery: discovery
    )
    let session = ShrinkSession(runner: self, context: context)
    return session.minimize(property: property)
  }

  /// Minimizes a failing trace for an async property.
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
    let context = ShrinkContext(
      trace: initialTrace,
      errorMessage: errorMessage,
      value: initialValue,
      runCount: runCount,
      seed: seed,
      statistics: statistics,
      discovery: discovery
    )
    let session = ShrinkSession(runner: self, context: context)
    return await session.minimize(property: property)
  }
  func minimizeDataAwareTrace(
    initialTrace: ChoiceTrace,
    maxIterations: Int,
    property: @escaping @Sendable (Value, inout PremiseData) throws -> Void
  ) -> (trace: ChoiceTrace, iterations: Int) {
    var shrinker = DataAwareTraceShrinker(
      runner: self,
      property: property,
      maxIterations: maxIterations,
      bestTrace: initialTrace
    )
    return shrinker.run()
  }

  func minimizeIfNeeded(
    failure: ExecutionFailure<Value>,
    runCount: Int,
    property: @escaping @Sendable (Value, inout PremiseData) throws -> Void,
    seed: UInt64?,
    discovery: FailureDiscovery
  ) -> (record: FailureRecord, value: Value) {
    let context = ShrinkContext.from(
      failure: failure,
      runCount: runCount,
      seed: seed,
      discovery: discovery
    )
    let session = ShrinkSession(runner: self, context: context)
    if let flaky = session.checkFlakiness(replay: {
      executeSingle(trace: context.trace, property: property)
    }) {
      return flaky
    }
    guard config.phases.includes(.shrink) else {
      return context.unshrunk(failure)
    }
    return session.minimize(property: property)
  }

  func minimizeIfNeeded(
    failure: ExecutionFailure<Value>,
    runCount: Int,
    property: @escaping @Sendable (Value) async throws -> Void,
    seed: UInt64?,
    discovery: FailureDiscovery
  ) async -> (record: FailureRecord, value: Value) {
    let context = ShrinkContext.from(
      failure: failure,
      runCount: runCount,
      seed: seed,
      discovery: discovery
    )
    let session = ShrinkSession(runner: self, context: context)
    if let flaky = await session.checkFlakinessAsync(replay: {
      await executeSingleAsync(trace: context.trace, property: property)
    }) {
      return flaky
    }
    guard config.phases.includes(.shrink) else {
      return context.unshrunk(failure)
    }
    return await session.minimize(property: property)
  }
}
