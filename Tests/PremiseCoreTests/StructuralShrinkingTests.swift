import Testing

@testable import PremiseCore
@testable import PremiseStrategies

private enum StructuralFailure: Error {
  case boom
}

@Test("ShrinkMachine reduces a failing integer to the smallest failing bound")
func shrinkMachineReducesAFailingIntegerToTheSmallestFailingBound() async {
  let strategy = Strategy<Int>.integers(in: 2...9)
  let propertyID = PropertyIdentity(
    fileID: "StructuralShrinkingTests",
    line: 1,
    strategyLabel: strategy.label
  )
  let runner = Runner(
    strategy: strategy,
    config: PropertyConfig(maxRuns: 1, maxShrinkIterations: 16, maxDrawsPerRun: 8, seed: 1),
    propertyID: propertyID
  )

  let property: @Sendable (Int) throws -> Void = { value in
    if value >= 2 {
      throw StructuralFailure.boom
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

  #expect(value == 2)
}
