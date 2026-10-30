struct ShrinkSession<Value: Sendable> {
  let runner: Runner<Value>
  let context: ShrinkContext<Value>

  func minimize(
    property: @escaping @Sendable (Value) throws -> Void
  ) -> (record: FailureRecord, value: Value) {
    if let flaky = checkFlakiness(replay: {
      runner.executeSingle(trace: context.trace, property: property)
    }) {
      return flaky
    }
    guard runner.config.maxShrinkIterations > 0 else {
      return result(trace: context.trace, iterations: 0, rerun: nil)
    }
    return shrink(property: property)
  }

  func minimize(
    property: @escaping @Sendable (Value, inout PremiseData) throws -> Void
  ) -> (record: FailureRecord, value: Value) {
    if let flaky = checkFlakiness(replay: {
      runner.executeSingle(trace: context.trace, property: property)
    }) {
      return flaky
    }
    guard runner.config.maxShrinkIterations > 0 else {
      return result(trace: context.trace, iterations: 0, rerun: nil)
    }
    return shrink(property: property)
  }

  func minimize(
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> (record: FailureRecord, value: Value) {
    if let flaky = await checkFlakinessAsync(replay: {
      await runner.executeSingleAsync(trace: context.trace, property: property)
    }) {
      return flaky
    }
    guard runner.config.maxShrinkIterations > 0 else {
      return result(trace: context.trace, iterations: 0, rerun: nil)
    }
    return await shrink(property: property)
  }

}

extension ShrinkSession {
  func checkFlakiness(
    replay: () -> ExecutionFailure<Value>?
  ) -> (record: FailureRecord, value: Value)? {
    runner.flakinessFailureIfNeeded(
      initialTrace: context.trace,
      errorMessage: context.errorMessage,
      initialValue: context.value,
      runCount: context.runCount,
      seed: context.seed,
      statistics: context.statistics,
      discovery: context.discovery,
      replay: replay
    )
  }

  func checkFlakinessAsync(
    replay: () async -> ExecutionFailure<Value>?
  ) async -> (record: FailureRecord, value: Value)? {
    await runner.flakinessFailureIfNeededAsync(
      initialTrace: context.trace,
      errorMessage: context.errorMessage,
      initialValue: context.value,
      runCount: context.runCount,
      seed: context.seed,
      statistics: context.statistics,
      discovery: context.discovery,
      replay: replay
    )
  }

  private func shrink(
    property: @escaping @Sendable (Value) throws -> Void
  ) -> (record: FailureRecord, value: Value) {
    var machine = ShrinkMachine(
      runner: runner,
      property: property,
      bestTrace: context.trace,
      maxIterations: runner.config.maxShrinkIterations
    )
    let trace = machine.run()
    let rerun = runner.executeSingle(trace: trace, property: property)
    return result(trace: trace, iterations: machine.iterations, rerun: rerun)
  }

  private func shrink(
    property: @escaping @Sendable (Value, inout PremiseData) throws -> Void
  ) -> (record: FailureRecord, value: Value) {
    let shrink = runner.minimizeDataAwareTrace(
      initialTrace: context.trace,
      maxIterations: runner.config.maxShrinkIterations,
      property: property
    )
    let rerun = runner.executeSingle(trace: shrink.trace, property: property)
    return result(
      trace: shrink.trace,
      iterations: shrink.iterations,
      rerun: rerun
    )
  }

  private func shrink(
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> (record: FailureRecord, value: Value) {
    var machine = AsyncShrinkMachine(
      runner: runner,
      property: property,
      bestTrace: context.trace,
      maxIterations: runner.config.maxShrinkIterations
    )
    let trace = await machine.run()
    let rerun = await runner.executeSingleAsync(
      trace: trace,
      property: property
    )
    return result(trace: trace, iterations: machine.iterations, rerun: rerun)
  }

  private func result(
    trace: ChoiceTrace,
    iterations: Int,
    rerun: ExecutionFailure<Value>?
  ) -> (record: FailureRecord, value: Value) {
    let record = FailureRecord(
      propertyID: runner.propertyID,
      trace: rerun == nil ? context.trace : trace,
      errorMessage: rerun?.record.errorMessage ?? context.errorMessage,
      runCount: context.runCount,
      shrinkCount: iterations,
      seed: context.seed,
      discovery: context.discovery,
      statistics: rerun?.record.statistics ?? context.statistics
    )
    if let rerun { return (record, rerun.value) }
    return (record, context.value)
  }
}
