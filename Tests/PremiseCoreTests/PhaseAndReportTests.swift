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

@Test("Expected-failing explicit examples do not fail the run")
func expectedFailingExplicitExamplePassesWhenPropertyFails() async {
  let runner = Runner(
    strategy: Strategy<Int>.just(99),
    config: PropertyConfig(maxRuns: 10, seed: 1).phases([.explicit])
  )

  let result = await runner.runDetailed(
    examples: [.xfail(3, reason: "known bad input")]
  ) { value in
    if value == 3 {
      throw PhaseTestError.failed("explicit example failed as expected")
    }
  }

  guard case .passed(let report) = result else {
    Issue.record("Expected xfail explicit example to pass the run")
    return
  }

  #expect(report.runCount == 1)
  #expect(report.phaseCounts[.explicit] == 1)
}

@Test("Expected-failing explicit examples fail if the property passes")
func expectedFailingExplicitExampleFailsWhenPropertyPasses() async {
  let runner = Runner(
    strategy: Strategy<Int>.just(99),
    config: PropertyConfig(maxRuns: 10, seed: 1).phases([.explicit])
  )

  let result = await runner.runDetailed(
    examples: [.xfail(3, reason: "known bad input")]
  ) { _ in }

  guard case .failure(let record, let value, let report) = result else {
    Issue.record("Expected unmet xfail to fail the run")
    return
  }

  #expect(value == 3)
  #expect(record.errorMessage.contains("Expected explicit example to fail"))
  #expect(report.phaseCounts[.explicit] == 1)
}

@Test("Property-body assumptions reject examples without failing")
func propertyBodyAssumptionsRejectExamples() async {
  let runner = Runner(
    strategy: Strategy<Int>.just(1),
    config: PropertyConfig(maxRuns: 5, seed: 1)
  )

  let result = await runner.runDetailed { _, data in
    try data.assume(false, reason: "domain precondition")
  }

  guard case .passed(let report) = result else {
    Issue.record("Expected all rejected examples to produce a passing empty search")
    return
  }

  #expect(report.runCount == 0)
  #expect(report.rejectedCount == 5)
  #expect(report.rejectionCounts[.property] == 5)
}

@Test("Derandomized config derives a stable seed from property identity")
func derandomizedConfigUsesStablePropertySeed() async {
  let propertyID = PropertyIdentity(
    fileID: "PhaseAndReportTests.swift",
    line: 123,
    strategyLabel: "just(1)",
    functionName: "derandomizedConfigUsesStablePropertySeed"
  )
  let config = PropertyConfig(maxRuns: 1).derandomize()
  let first = Runner(strategy: Strategy<Int>.just(1), config: config, propertyID: propertyID)
  let second = Runner(strategy: Strategy<Int>.just(1), config: config, propertyID: propertyID)

  let firstResult = await first.runDetailed { _ in
    throw PhaseTestError.failed("fail")
  }
  let secondResult = await second.runDetailed { _ in
    throw PhaseTestError.failed("fail")
  }

  guard case .failure(let firstRecord, _, _) = firstResult,
    case .failure(let secondRecord, _, _) = secondResult
  else {
    Issue.record("Expected both derandomized runs to fail")
    return
  }

  #expect(firstRecord.seed == secondRecord.seed)
}

@Test("Per-example deadline reports a failure")
func perExampleDeadlineReportsFailure() async {
  let runner = Runner(
    strategy: Strategy<Int>.just(1),
    config: PropertyConfig(maxRuns: 1, seed: 1).deadline(seconds: -1)
  )

  let result = await runner.runDetailed { _ in }

  guard case .failure(let record, _, _) = result else {
    Issue.record("Expected deadline failure")
    return
  }

  #expect(record.errorMessage.contains("Example exceeded deadline"))
}
