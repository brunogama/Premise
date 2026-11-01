import Foundation
import Testing

@testable import PremiseCore
@testable import PremiseStrategies

@Test("Synchronous phase retains its report across repeated failures")
func synchronousPhaseRetainsFailureReport() async {
  let runner = repeatedFailureRunner()
  let result = await runner.runDetailed { _, data in
    data.event("attempt")
    throw CocoaError(.fileNoSuchFile)
  }
  guard case .failure(let record, _, let report) = result else {
    Issue.record("Expected a failure")
    return
  }
  #expect(record.runCount == 1)
  #expect(record.seed == 41)
  #expect(record.discovery == .newFailure)
  #expect(report.runCount == 3)
  #expect(report.phaseCounts[.generate] == 3)
  #expect(report.failures.count == 1)
  #expect(report.events["attempt"] == 3)
}

@Test("Asynchronous phase retains its report across repeated failures")
func asynchronousPhaseRetainsFailureReport() async {
  let runner = repeatedFailureRunner()
  let result = await runner.runDetailed { _ async throws in
    await Task.yield()
    throw CocoaError(.fileNoSuchFile)
  }
  guard case .failure(let record, _, let report) = result else {
    Issue.record("Expected a failure")
    return
  }
  #expect(record.runCount == 1)
  #expect(record.seed == 41)
  #expect(record.discovery == .newFailure)
  #expect(report.runCount == 3)
  #expect(report.phaseCounts[.generate] == 3)
  #expect(report.failures.count == 1)
}

@Test("Synchronous early phase failure preserves earlier report")
func synchronousEarlyFailurePreservesReport() async {
  let runner = firstFailureRunner()
  let result = await runner.runDetailed(explicitExamples: [0]) { value, data in
    data.event("visited")
    if value == 1 { throw CocoaError(.fileNoSuchFile) }
  }
  guard case .failure(let record, _, let report) = result else {
    Issue.record("Expected a failure")
    return
  }
  #expect(record.seed == 41)
  #expect(report.runCount == 2)
  #expect(report.phaseCounts[.explicit] == 1)
  #expect(report.phaseCounts[.generate] == 1)
  #expect(report.events["visited"] == 2)
  #expect(report.failures.count == 1)
}

@Test("Asynchronous early phase failure preserves earlier report")
func asynchronousEarlyFailurePreservesReport() async {
  let runner = firstFailureRunner()
  let result = await runner.runDetailed(
    explicitExamples: [0]
  ) { value async throws in
    await Task.yield()
    if value == 1 { throw CocoaError(.fileNoSuchFile) }
  }
  guard case .failure(let record, _, let report) = result else {
    Issue.record("Expected a failure")
    return
  }
  #expect(record.seed == 41)
  #expect(report.runCount == 2)
  #expect(report.phaseCounts[.explicit] == 1)
  #expect(report.phaseCounts[.generate] == 1)
  #expect(report.failures.count == 1)
}

private func firstFailureRunner() -> Runner<Int> {
  Runner(
    strategy: Strategy<Int>.just(1),
    config: PropertyConfig(maxRuns: 3, seed: 41)
      .phases([.explicit, .generate])
      .noShrink()
  )
}

private func repeatedFailureRunner() -> Runner<Int> {
  Runner(
    strategy: Strategy<Int>.just(1),
    config: PropertyConfig(maxRuns: 3, seed: 41)
      .phases([.generate])
      .noShrink()
      .reportingMultipleBugs(.all)
  )
}
