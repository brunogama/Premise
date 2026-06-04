import Testing

@testable import PremiseCore
@testable import PremiseStrategies

private enum PhaseTestError: Error, CustomStringConvertible {
  case failed(String)

  var description: String {
    switch self {
    case .failed(let message): return message
    }
  }
}

@Test("Explicit examples run before generated examples")
func explicitExamplesRunBeforeGeneration() async {
  let strategy = Strategy<Int>.just(99)
  let runner = Runner(
    strategy: strategy,
    config: PropertyConfig(maxRuns: 10, seed: 1)
  )

  let result = await runner.runDetailed(
    explicitExamples: [3]
  ) { value in
    if value == 3 {
      throw PhaseTestError.failed("explicit example failed")
    }
  }

  guard case .failure(let record, let value, let report) = result else {
    Issue.record("Expected explicit example failure")
    return
  }

  #expect(value == 3)
  #expect(record.runCount == 0)
  #expect(report.phaseCounts[.explicit] == 1)
  #expect(report.phaseCounts[.generate] == nil)
}

@Test("Generation phase can be disabled")
func generationPhaseCanBeDisabled() async {
  let strategy = Strategy<Int>.just(99)
  let config = PropertyConfig(maxRuns: 10, seed: 1)
    .phases([.explicit])
  let runner = Runner(strategy: strategy, config: config)

  let result = await runner.runDetailed(explicitExamples: [1, 2]) { value in
    #expect(value == 1 || value == 2)
  }

  guard case .passed(let report) = result else {
    Issue.record("Expected pass with explicit-only phases")
    return
  }

  #expect(report.runCount == 2)
  #expect(report.phaseCounts[.explicit] == 2)
  #expect(report.phaseCounts[.generate] == nil)
}

@Test("Run report aggregates events notes and target scores")
func runReportAggregatesStatistics() async {
  let strategy = Strategy<Int>.integers(in: 0...2)
  let runner = Runner(
    strategy: strategy,
    config: PropertyConfig(maxRuns: 3, seed: 1)
  )

  let result = await runner.runDetailed { value, data in
    data.event(value.isMultiple(of: 2) ? "even" : "odd")
    data.note("value", value: value)
    data.target(Double(value), label: "magnitude")
  }

  guard case .passed(let report) = result else {
    Issue.record("Expected passing detailed run")
    return
  }

  #expect(report.runCount == 3)
  #expect(report.events.values.reduce(0, +) == 3)
  #expect(report.notes.count == 3)
  #expect(report.maxTargetScore != nil)
}
