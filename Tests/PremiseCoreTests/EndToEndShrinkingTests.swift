import Testing

@testable import PremiseCore
@testable import PremiseStrategies

private enum EndToEndFailure: Error {
  case boom
}

@Test("Collections shrink by removing elements and replaying the smaller failing case")
func collectionsShrinkByRemovingElements() async {
  let strategy = Strategy<Int>.arrays(of: .just(1), length: 2...4)
  let propertyID = PropertyIdentity(
    fileID: "EndToEndShrinkingTests",
    line: 1,
    strategyLabel: strategy.label
  )
  let runner = Runner(
    strategy: strategy,
    config: PropertyConfig(maxRuns: 1, maxShrinkIterations: 16, maxDrawsPerRun: 16, seed: 2),
    propertyID: propertyID
  )

  let property: @Sendable ([Int]) throws -> Void = { values in
    if values.count >= 2 {
      throw EndToEndFailure.boom
    }
  }

  let result = await runner.run(property)
  guard case .failure(let record, _) = result else {
    #expect(Bool(false))
    return
  }

  var shrinkMachine = ShrinkMachine(
    runner: runner,
    property: property,
    bestTrace: record.trace,
    maxIterations: 16
  )
  let shrunkTrace = shrinkMachine.run()

  #expect(shrunkTrace.entries.count <= record.trace.entries.count)

  let replayResult = await runner.run(property, replayTraces: [shrunkTrace])
  guard case .failure(_, let value) = replayResult else {
    #expect(Bool(false))
    return
  }

  #expect(value.count == 2)
}

@Test("FlatMap dependent strategies still shrink to a failing invariant")
func flatMapDependentStrategiesStillShrink() async {
  let strategy = Strategy<Int>.integers(in: 2...4).flatMap { length in
    Strategy<Int>.arrays(of: .just(1), length: length...length)
  }
  let propertyID = PropertyIdentity(
    fileID: "EndToEndShrinkingTests",
    line: 2,
    strategyLabel: strategy.label
  )
  let runner = Runner(
    strategy: strategy,
    config: PropertyConfig(maxRuns: 1, maxShrinkIterations: 16, maxDrawsPerRun: 32, seed: 3),
    propertyID: propertyID
  )

  let property: @Sendable ([Int]) throws -> Void = { values in
    if values.count >= 2 {
      throw EndToEndFailure.boom
    }
  }

  let result = await runner.run(property)
  guard case .failure(let record, _) = result else {
    #expect(Bool(false))
    return
  }

  let originalCount = record.trace.entries.count
  var shrinkMachine = ShrinkMachine(
    runner: runner,
    property: property,
    bestTrace: record.trace,
    maxIterations: 16
  )
  let shrunkTrace = shrinkMachine.run()

  #expect(shrunkTrace.entries.count <= originalCount)

  let replayResult = await runner.run(property, replayTraces: [shrunkTrace])
  guard case .failure(_, let value) = replayResult else {
    #expect(Bool(false))
    return
  }

  #expect(value.count == 2)
}

@Test("map-based strategies still replay the minimized failing example")
func mapBasedStrategiesStillReplayTheMinimizedFailure() async {
  let strategy = Strategy<Int>.integers(in: 2...8).map { $0 * 2 }
  let propertyID = PropertyIdentity(
    fileID: "EndToEndShrinkingTests",
    line: 3,
    strategyLabel: strategy.label
  )
  let runner = Runner(
    strategy: strategy,
    config: PropertyConfig(maxRuns: 1, maxShrinkIterations: 16, maxDrawsPerRun: 16, seed: 4),
    propertyID: propertyID
  )

  let property: @Sendable (Int) throws -> Void = { value in
    if value >= 4 {
      throw EndToEndFailure.boom
    }
  }

  let result = await runner.run(property)
  guard case .failure(let record, _) = result else {
    #expect(Bool(false))
    return
  }

  var shrinkMachine = ShrinkMachine(
    runner: runner,
    property: property,
    bestTrace: record.trace,
    maxIterations: 16
  )
  let shrunkTrace = shrinkMachine.run()
  let replayResult = await runner.run(property, replayTraces: [shrunkTrace])

  guard case .failure(_, let value) = replayResult else {
    #expect(Bool(false))
    return
  }

  #expect(value == 4)
}
