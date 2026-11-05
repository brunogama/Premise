import Testing

@testable import PremiseCore

private enum ShrinkerTestError: Error {
  case failure
}

@Test("Data-aware shrinking preserves deletion and iteration ordering")
func dataAwareShrinkingPreservesOrdering() {
  let runner = Runner(
    strategy: Strategy<Int>.just(1),
    config: PropertyConfig(maxShrinkIterations: 4)
  )
  let trace = ChoiceTrace(
    entries: [.integer(7), .integer(4)],
    spans: [.init(start: 1, end: 2)]
  )
  let result = runner.minimizeTrace(
    initialTrace: trace,
    errorMessage: String(describing: ShrinkerTestError.failure),
    initialValue: 1,
    runCount: 1,
    property: { _, _ in throw ShrinkerTestError.failure },
    seed: nil
  )
  #expect(result.record.trace.entries == [.integer(0)])
  #expect(result.record.trace.spans.isEmpty)
  #expect(result.record.shrinkCount == 4)
  #expect(result.value == 1)
}
