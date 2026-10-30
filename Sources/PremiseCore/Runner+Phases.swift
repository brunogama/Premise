import Foundation

extension Runner {
  func runGeneratePhase(
    report: inout RunReport,
    property: @escaping @Sendable (Value, inout PremiseData) throws -> Void
  ) -> (record: FailureRecord, value: Value)? {
    runPhase(.generate, report: &report, property: property)
  }

  func runTargetPhase(
    report: inout RunReport,
    property: @escaping @Sendable (Value, inout PremiseData) throws -> Void
  ) -> (record: FailureRecord, value: Value)? {
    runPhase(.target, report: &report, property: property)
  }

  func runGeneratePhaseAsync(
    report: inout RunReport,
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> (record: FailureRecord, value: Value)? {
    await runPhaseAsync(.generate, report: &report, property: property)
  }

  func runTargetPhaseAsync(
    report: inout RunReport,
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> (record: FailureRecord, value: Value)? {
    await runPhaseAsync(.target, report: &report, property: property)
  }

  private func runPhase(
    _ phase: PropertyPhase,
    report: inout RunReport,
    property: @escaping @Sendable (Value, inout PremiseData) throws -> Void
  ) -> (record: FailureRecord, value: Value)? {
    var state = makePhaseState(phase)
    for index in 0..<config.maxRuns {
      if let deadline = state.deadline, Date() > deadline { break }
      let attempt = phaseAttempt(state, index: index, property: property)
      if let failure = processPhaseAttempt(
        attempt,
        index: index,
        state: &state,
        report: &report,
        property: property
      ) {
        return failure
      }
    }
    return state.firstFailure
  }

  private func runPhaseAsync(
    _ phase: PropertyPhase,
    report: inout RunReport,
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> (record: FailureRecord, value: Value)? {
    var state = makePhaseState(phase)
    for index in 0..<config.maxRuns {
      if let deadline = state.deadline, Date() > deadline { break }
      let attempt = await phaseAttemptAsync(
        state,
        index: index,
        property: property
      )
      if let failure = await processPhaseAttemptAsync(
        attempt,
        index: index,
        state: &state,
        report: &report,
        property: property
      ) {
        return failure
      }
    }
    return state.firstFailure
  }

  private func makePhaseState(_ phase: PropertyPhase) -> PhaseRunState<Value> {
    let seed = makeBaseSeed() ^ (phase == .target ? 0x7461_7267_6574_0001 : 0)
    let deadline = config.timeoutSeconds.map { Date(timeIntervalSinceNow: $0) }
    return PhaseRunState(phase: phase, seed: seed, deadline: deadline)
  }

  private func phaseAttempt(
    _ state: PhaseRunState<Value>,
    index: Int,
    property: @Sendable (Value, inout PremiseData) throws -> Void
  ) -> ExecutionAttempt<Value> {
    if let trace = state.mutation(index: index) {
      return executeAttempt(trace: trace, property: property)
    }
    let provider = PseudoRandomProvider(
      seed: state.seed &+ UInt64(index),
      maxDraws: config.maxDrawsPerRun
    )
    return executeAttempt(provider: provider, property: property)
  }

  private func phaseAttemptAsync(
    _ state: PhaseRunState<Value>,
    index: Int,
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> ExecutionAttempt<Value> {
    if let trace = state.mutation(index: index) {
      return await executeAttemptAsync(trace: trace, property: property)
    }
    let provider = PseudoRandomProvider(
      seed: state.seed &+ UInt64(index),
      maxDraws: config.maxDrawsPerRun
    )
    return await executeAttemptAsync(provider: provider, property: property)
  }

  private func processPhaseAttempt(
    _ attempt: ExecutionAttempt<Value>,
    index: Int,
    state: inout PhaseRunState<Value>,
    report: inout RunReport,
    property: @escaping @Sendable (Value, inout PremiseData) throws -> Void
  ) -> (record: FailureRecord, value: Value)? {
    guard case .failure(let failure) = attempt else {
      state.record(attempt, report: &report)
      return nil
    }
    let minimized = minimizeIfNeeded(
      failure: failure,
      runCount: index + 1,
      property: property,
      seed: state.seed,
      discovery: .newFailure
    )
    return recordPhaseFailure(minimized, state: &state, report: &report)
  }

  private func processPhaseAttemptAsync(
    _ attempt: ExecutionAttempt<Value>,
    index: Int,
    state: inout PhaseRunState<Value>,
    report: inout RunReport,
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> (record: FailureRecord, value: Value)? {
    guard case .failure(let failure) = attempt else {
      state.record(attempt, report: &report)
      return nil
    }
    let minimized = await minimizeIfNeeded(
      failure: failure,
      runCount: index + 1,
      property: property,
      seed: state.seed,
      discovery: .newFailure
    )
    return recordPhaseFailure(minimized, state: &state, report: &report)
  }

  private func recordPhaseFailure(
    _ failure: (record: FailureRecord, value: Value),
    state: inout PhaseRunState<Value>,
    report: inout RunReport
  ) -> (record: FailureRecord, value: Value)? {
    report.recordPhase(state.phase)
    report.merge(failure.record.statistics)
    let isNew = state.recordFailure(failure.record, report: &report)
    if state.firstFailure == nil, isNew { state.firstFailure = failure }
    return config.multipleBugReporting == .first ? failure : nil
  }
}
