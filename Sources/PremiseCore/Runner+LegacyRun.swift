import Foundation

extension Runner {
  func legacyReplay(
    _ traces: [ChoiceTrace],
    property: @escaping @Sendable (Value) throws -> Void
  ) -> RunResult<Value>? {
    guard config.replayEnabled else { return nil }
    for trace in traces {
      if let failure = executeSingle(trace: trace, property: property) {
        return legacyFailure(
          failure,
          runCount: 1,
          seed: failure.record.seed,
          discovery: .knownFailure,
          property: property
        )
      }
    }
    return nil
  }

  func legacyReplayAsync(
    _ traces: [ChoiceTrace],
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> RunResult<Value>? {
    guard config.replayEnabled else { return nil }
    for trace in traces {
      if let failure = await executeSingleAsync(
        trace: trace,
        property: property
      ) {
        return await legacyFailureAsync(
          failure,
          runCount: 1,
          seed: failure.record.seed,
          discovery: .knownFailure,
          property: property
        )
      }
    }
    return nil
  }

  func legacyGenerate(
    property: @escaping @Sendable (Value) throws -> Void
  ) -> RunResult<Value> {
    let seed = makeBaseSeed()
    let deadline = config.timeoutSeconds.map { Date(timeIntervalSinceNow: $0) }
    for index in 0..<config.maxRuns {
      if let deadline, Date() > deadline { return .passed(runs: index) }
      let provider = legacyProvider(seed: seed, index: index)
      if let failure = executeSingle(provider: provider, property: property) {
        return legacyFailure(
          failure,
          runCount: index + 1,
          seed: seed,
          discovery: .newFailure,
          property: property
        )
      }
    }
    return .passed(runs: config.maxRuns)
  }

  func legacyGenerateAsync(
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> RunResult<Value> {
    let seed = makeBaseSeed()
    let deadline = config.timeoutSeconds.map { Date(timeIntervalSinceNow: $0) }
    for index in 0..<config.maxRuns {
      if let deadline, Date() > deadline { return .passed(runs: index) }
      let provider = legacyProvider(seed: seed, index: index)
      if let failure = await executeSingleAsync(
        provider: provider,
        property: property
      ) {
        return await legacyFailureAsync(
          failure,
          runCount: index + 1,
          seed: seed,
          discovery: .newFailure,
          property: property
        )
      }
    }
    return .passed(runs: config.maxRuns)
  }

  private func legacyProvider(
    seed: UInt64,
    index: Int
  ) -> PseudoRandomProvider {
    PseudoRandomProvider(
      seed: seed &+ UInt64(index),
      maxDraws: config.maxDrawsPerRun
    )
  }

  private func legacyFailure(
    _ failure: ExecutionFailure<Value>,
    runCount: Int,
    seed: UInt64?,
    discovery: FailureDiscovery,
    property: @escaping @Sendable (Value) throws -> Void
  ) -> RunResult<Value> {
    let context = ShrinkContext.from(
      failure: failure,
      runCount: runCount,
      seed: seed,
      discovery: discovery
    )
    let session = ShrinkSession(runner: self, context: context)
    let result = session.minimize(property: property)
    return .failure(result.record, value: result.value)
  }

  private func legacyFailureAsync(
    _ failure: ExecutionFailure<Value>,
    runCount: Int,
    seed: UInt64?,
    discovery: FailureDiscovery,
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> RunResult<Value> {
    let context = ShrinkContext.from(
      failure: failure,
      runCount: runCount,
      seed: seed,
      discovery: discovery
    )
    let result = await ShrinkSession(runner: self, context: context).minimize(
      property: property
    )
    return .failure(result.record, value: result.value)
  }
}
