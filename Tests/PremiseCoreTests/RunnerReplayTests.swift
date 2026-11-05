import Testing

@testable import PremiseCore

private enum ReplayFailure: Error {
  case boom
}

private typealias ReplayProperty = @Sendable (Int) throws -> Void

@Test("Runner replays stored failures")
func runnerReplaysStoredFailures() async {
  let runner = replayRunner()
  let property: @Sendable (Int) throws -> Void = replayFailureProperty

  let result = await runner.run(property)
  guard case .failure(let record, let value) = result else {
    #expect(Bool(false))
    return
  }

  #expect(value == 0)
  let replay: (ChoiceTrace, ReplayProperty) -> Bool = runner.replay
  let reproduced = replay(record.trace, property)
  #expect(reproduced)

  let replayResult = await runner.run(property, replayTraces: [record.trace])
  guard case .failure(let replayRecord, let replayValue) = replayResult else {
    #expect(Bool(false))
    return
  }

  #expect(replayRecord.trace == record.trace)
  #expect(replayValue == value)
}

private func replayRunner() -> Runner<Int> {
  let strategy = Strategy<Int>.just(0)
  let propertyID = PropertyIdentity(
    fileID: "RunnerReplayTests",
    line: 1,
    strategyLabel: strategy.label
  )
  let config = PropertyConfig(
    maxRuns: 1,
    maxShrinkIterations: 4,
    maxDrawsPerRun: 8,
    seed: 1
  )
  return Runner(strategy: strategy, config: config, propertyID: propertyID)
}

private func replayFailureProperty(_ value: Int) throws {
  if value == 0 {
    throw ReplayFailure.boom
  }
}
