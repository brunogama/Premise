import Testing

@testable import PremiseCore
@testable import PremiseTesting
@testable import PremiseStrategies

private enum CounterOperation: ModelOperation, Equatable {
  case insert(Int)
  case remove(Int)

  func apply(to model: inout Set<Int>) throws {
    switch self {
    case .insert(let value):
      model.insert(value)

    case .remove(let value):
      model.remove(value)
    }
  }

  func run(on system: inout Set<Int>) async throws {
    await Task.yield()
    try apply(to: &system)
  }
}

@Test("Operation sequence strategy shrinks by removing operations")
func operationSequenceStrategyShrinksByRemovingOperations() {
  let operation = Strategy<CounterOperation>.just(.insert(1))
  let sequence = Strategy<[CounterOperation]>.operationSequences(
    of: operation,
    length: 1...4
  )

  let shrinks = sequence.shrink([.insert(1), .insert(1), .insert(1)])
  #expect(shrinks.contains([.insert(1), .insert(1)]))
}

@Test("Model checker runs operations against model and system")
func modelCheckerRunsOperationsAgainstModelAndSystem() async throws {
  let operations: [CounterOperation] = [.insert(1), .insert(2), .remove(1)]

  try await checkOperationSequence(
    operations,
    initialModel: Set<Int>(),
    initialSystem: Set<Int>()
  ) { model, system in
    #expect(model == system)
  }
}
