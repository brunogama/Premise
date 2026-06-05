import Testing

@testable import PremiseCore

private enum AsyncRunnerFailure: Error {
  case boom
}

@Test("Runner supports async properties and marks fresh failures")
func runnerSupportsAsyncPropertiesAndMarksFreshFailures() async {
  let strategy = Strategy<Int>.just(42)
  let propertyID = PropertyIdentity(
    fileID: "AsyncRunnerTests",
    line: 1,
    strategyLabel: strategy.label,
    functionName: "runnerSupportsAsyncPropertiesAndMarksFreshFailures"
  )
  let runner = Runner(
    strategy: strategy,
    config: PropertyConfig(maxRuns: 1, seed: 123),
    propertyID: propertyID
  )

  let result = await runner.run { value in
    await Task.yield()
    if value == 42 {
      throw AsyncRunnerFailure.boom
    }
  }

  guard case .failure(let record, let value) = result else {
    Issue.record("Expected async property failure")
    return
  }

  #expect(value == 42)
  #expect(record.seed == 123)
  #expect(record.discovery == .newFailure)
}

@Test("Runner marks replayed failures as known failures")
func runnerMarksReplayedFailuresAsKnownFailures() async {
  let strategy = Strategy<Int>.just(7)
  let propertyID = PropertyIdentity(
    fileID: "AsyncRunnerTests",
    line: 2,
    strategyLabel: strategy.label,
    functionName: "runnerMarksReplayedFailuresAsKnownFailures"
  )
  let runner = Runner(
    strategy: strategy,
    config: PropertyConfig(maxRuns: 0, seed: 999),
    propertyID: propertyID
  )

  let initialRecord = FailureRecord(
    propertyID: propertyID,
    trace: ChoiceTrace(),
    errorMessage: "known failure",
    seed: 999,
    discovery: .newFailure
  )

  let result = await runner.run(
    { value in
      if value == 7 {
        throw AsyncRunnerFailure.boom
      }
    },
    replayTraces: [initialRecord.trace]
  )

  guard case .failure(let record, let value) = result else {
    Issue.record("Expected known replay failure")
    return
  }

  #expect(value == 7)
  #expect(record.discovery == .knownFailure)
}
