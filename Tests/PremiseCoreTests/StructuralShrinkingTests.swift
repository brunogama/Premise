import Testing

@testable import PremiseCore
@testable import PremiseStrategies

private enum StructuralFailure: Error {
  case boom
}

@Test("ShrinkMachine reduces a failing integer to the smallest failing bound")
func shrinkMachineReducesAFailingIntegerToTheSmallestFailingBound() async {
  let runner = structuralShrinkRunner()

  let property: @Sendable (Int) throws -> Void = structuralProperty

  let result = await runner.run(property)
  guard case .failure(let record, _) = result else {
    #expect(Bool(false))
    return
  }

  let shrunkTrace = shrinkTrace(
    record.trace,
    runner: runner,
    property: property
  )

  let replayResult = await runner.run(property, replayTraces: [shrunkTrace])
  guard case .failure(_, let value) = replayResult else {
    #expect(Bool(false))
    return
  }

  #expect(value == 2)
}

private func structuralProperty(_ value: Int) throws {
  if value >= 2 {
    throw StructuralFailure.boom
  }
}
private func structuralShrinkRunner() -> Runner<Int> {
  let strategy = Strategy<Int>.integers(in: 2...9)
  let propertyID = PropertyIdentity(
    fileID: "StructuralShrinkingTests",
    line: 1,
    strategyLabel: strategy.label
  )
  return Runner(
    strategy: strategy,
    config: PropertyConfig(
      maxRuns: 1,
      maxShrinkIterations: 16,
      maxDrawsPerRun: 8,
      seed: 1
    ),
    propertyID: propertyID
  )
}

private func shrinkTrace(
  _ trace: ChoiceTrace,
  runner: Runner<Int>,
  property: @escaping @Sendable (Int) throws -> Void
) -> ChoiceTrace {
  var shrinkMachine = ShrinkMachine(
    runner: runner,
    property: property,
    bestTrace: trace,
    maxIterations: 16
  )
  return shrinkMachine.run()
}
