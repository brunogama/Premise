import Testing

@testable import PremiseCore

private enum ReplayFailure: Error {
  case boom
}

@Test("Runner replays stored failures")
func runnerReplaysStoredFailures() async {
  let strategy = Strategy<Int>.just(0)
  let propertyID = PropertyIdentity(
    fileID: "RunnerReplayTests",
    line: 1,
    strategyLabel: strategy.label
  )
  let runner = Runner(
    strategy: strategy,
    config: PropertyConfig(maxRuns: 1, maxShrinkIterations: 4, maxDrawsPerRun: 8, seed: 1),
    propertyID: propertyID
  )

  let property: @Sendable (Int) throws -> Void = { value in
    if value == 0 {
      throw ReplayFailure.boom
    }
  }

  let result = await runner.run(property)
  guard case .failure(let record, let value) = result else {
    #expect(Bool(false))
    return
  }

  #expect(value == 0)
  #expect(runner.replay(record.trace, property: property))

  let replayResult = await runner.run(property, replayTraces: [record.trace])
  guard case .failure(let replayRecord, let replayValue) = replayResult else {
    #expect(Bool(false))
    return
  }

  #expect(replayRecord.trace == record.trace)
  #expect(replayValue == value)
}
