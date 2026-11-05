import PremiseCore
import PremiseDatabase

struct StateMachineCheckRunner<State: Sendable> {
  let machine: RuleBasedStateMachine<State>
  let config: StateMachineConfig
  let database: FileBackedDatabase?
  let baseSeed: UInt64

  func run() async throws {
    if config.replayEnabled {
      let stored = try await database?.loadTraces(for: config.propertyID) ?? []
      for (index, trace) in (config.replayTraces + stored).enumerated() {
        try await replay(trace, index: -1 - index)
      }
    }
    for index in 0..<config.maxExamples {
      try await generate(index: index)
    }
  }

  private func replay(_ trace: ChoiceTrace, index: Int) async throws {
    let metadata = metadata(index)
    do {
      try await runOnce(
        machine,
        config: config,
        provider: ReplayProvider(trace: trace),
        metadata: metadata
      )
    } catch let failure as StateMachineFailure {
      try await persist(failure: failure, config: config, database: database)
      throw failure
    }
  }

  private func generate(index: Int) async throws {
    let metadata = metadata(index)
    let provider = provider(index)
    do {
      try await runOnce(
        machine,
        config: config,
        provider: provider,
        metadata: metadata
      )
    } catch let failure as StateMachineFailure {
      let minimized = await shrinkFailure(
        failure,
        machine: machine,
        config: config,
        metadata: metadata
      )
      try await persist(failure: minimized, config: config, database: database)
      throw minimized
    }
  }

  private func provider(_ index: Int) -> PseudoRandomProvider {
    PseudoRandomProvider(
      seed: baseSeed &+ UInt64(index),
      maxDraws: config.maxDrawsPerExample
    )
  }
  private func metadata(_ index: Int) -> StateMachineRunMetadata {
    StateMachineRunMetadata(baseSeed: baseSeed, exampleIndex: index)
  }
}
