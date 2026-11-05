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
          .from(
            failure: failure,
            runCount: 1,
            seed: failure.record.seed,
            discovery: .knownFailure
          ),
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
          .from(
            failure: failure,
            runCount: 1,
            seed: failure.record.seed,
            discovery: .knownFailure
          ),
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
          generatedShrinkContext(failure, index: index, seed: seed),
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
          generatedShrinkContext(failure, index: index, seed: seed),
          property: property
        )
      }
    }
    return .passed(runs: config.maxRuns)
  }

  private func generatedShrinkContext(
    _ failure: ExecutionFailure<Value>,
    index: Int,
    seed: UInt64
  ) -> ShrinkContext<Value> {
    .from(
      failure: failure,
      runCount: index + 1,
      seed: seed,
      discovery: .newFailure
    )
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
    _ context: ShrinkContext<Value>,
    property: @escaping @Sendable (Value) throws -> Void
  ) -> RunResult<Value> {
    let session = ShrinkSession(runner: self, context: context)
    let result = session.minimize(property: property)
    return .failure(result.record, value: result.value)
  }

  private func legacyFailureAsync(
    _ context: ShrinkContext<Value>,
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> RunResult<Value> {
    let result = await ShrinkSession(runner: self, context: context).minimize(
      property: property
    )
    return .failure(result.record, value: result.value)
  }
}
