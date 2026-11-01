import Testing

@testable import PremiseCore
@testable import PremiseStrategies

private enum EndToEndFailure: Error {
  case boom
}

@Test(
  """
  Collections shrink by removing elements \
  and replaying the smaller failing case
  """
)
func collectionsShrinkByRemovingElements() async {
  let strategy = Strategy<Int>.arrays(of: .just(1), length: 2...4)
  let runner = shrinkingRunner(strategy, line: 1, seed: 2)

  let property: @Sendable ([Int]) throws -> Void = failingCollectionProperty

  let result = await runner.run(property)
  guard case .failure(let record, _) = result else {
    #expect(Bool(false))
    return
  }

  let shrunkTrace = shrinkTrace(runner, property: property, trace: record.trace)

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
  let runner = dependentShrinkingRunner(strategy)

  let property: @Sendable ([Int]) throws -> Void = failingCollectionProperty

  let result = await runner.run(property)
  guard case .failure(let record, _) = result else {
    #expect(Bool(false))
    return
  }

  let originalCount = record.trace.entries.count
  let shrunkTrace = shrinkTrace(runner, property: property, trace: record.trace)

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
  let runner = shrinkingRunner(strategy, line: 3, seed: 4)

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

  let shrunkTrace = shrinkTrace(runner, property: property, trace: record.trace)
  let replayResult = await runner.run(property, replayTraces: [shrunkTrace])

  guard case .failure(_, let value) = replayResult else {
    #expect(Bool(false))
    return
  }

  #expect(value == 4)
}

private func failingCollectionProperty(_ values: [Int]) throws {
  if values.count >= 2 {
    throw EndToEndFailure.boom
  }
}

private func shrinkingRunner<Value>(
  _ strategy: Strategy<Value>,
  line: UInt,
  seed: UInt64
) -> Runner<Value> {
  let propertyID = PropertyIdentity(
    fileID: "EndToEndShrinkingTests",
    line: line,
    strategyLabel: strategy.label
  )
  let config = PropertyConfig(
    maxRuns: 1,
    maxShrinkIterations: 16,
    maxDrawsPerRun: 16,
    seed: seed
  )
  return Runner(strategy: strategy, config: config, propertyID: propertyID)
}

private func dependentShrinkingRunner(
  _ strategy: Strategy<[Int]>
) -> Runner<[Int]> {
  let propertyID = PropertyIdentity(
    fileID: "EndToEndShrinkingTests",
    line: 2,
    strategyLabel: strategy.label
  )
  let config = PropertyConfig(
    maxRuns: 1,
    maxShrinkIterations: 16,
    maxDrawsPerRun: 32,
    seed: 3
  )
  return Runner(strategy: strategy, config: config, propertyID: propertyID)
}

private func shrinkTrace<Value>(
  _ runner: Runner<Value>,
  property: @escaping @Sendable (Value) throws -> Void,
  trace: ChoiceTrace
) -> ChoiceTrace {
  var machine = ShrinkMachine(
    runner: runner,
    property: property,
    bestTrace: trace,
    maxIterations: 16
  )
  return machine.run()
}
