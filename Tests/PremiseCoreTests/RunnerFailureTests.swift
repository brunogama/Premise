import Testing

@testable import PremiseCore

private enum FailureTestsError: Error {
  case boom
}

@Test("Runner reports passed for a non-failing property")
func runnerReportsPassed() async {
  let strategy = Strategy<Int>.just(1)
  let runner = Runner(strategy: strategy, config: PropertyConfig(maxRuns: 1, seed: 1))

  let result = await runner.run { value in
    #expect(value == 1)
  }

  guard case .passed(let runs) = result else {
    #expect(Bool(false))
    return
  }

  #expect(runs == 1)
}

@Test("Runner reports failure with trace data")
func runnerReportsFailure() async {
  let strategy = Strategy<Int>.integers(in: 0...0)
  let propertyID = PropertyIdentity(
    fileID: "RunnerFailureTests",
    line: 1,
    strategyLabel: strategy.label
  )
  let runner = Runner(
    strategy: strategy,
    config: PropertyConfig(maxRuns: 1, seed: 1),
    propertyID: propertyID
  )

  let result = await runner.run { value in
    if value == 0 {
      throw FailureTestsError.boom
    }
  }

  guard case .failure(let record, let value) = result else {
    #expect(Bool(false))
    return
  }

  #expect(value == 0)
  #expect(
    record.trace.entries.contains { entry in
      if case .integer = entry {
        return true
      }
      return false
    }
  )
}
