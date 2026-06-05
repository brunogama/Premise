import PremiseCore
import PremiseStrategies

/// A single operation that can be applied to both a lightweight model and the
/// system under test.
public protocol ModelOperation: Sendable {
  associatedtype Model: Sendable
  associatedtype System: Sendable

  func apply(to model: inout Model) throws
  func run(on system: inout System) async throws
}

/// Runs a sequence of operations against a model and system, checking
/// equivalence after each step.
public func checkOperationSequence<Operation: ModelOperation>(
  _ operations: [Operation],
  initialModel: Operation.Model,
  initialSystem: Operation.System,
  assertEquivalent: (Operation.Model, Operation.System) throws -> Void
) async throws {
  var model = initialModel
  var system = initialSystem

  try assertEquivalent(model, system)
  for operation in operations {
    try operation.apply(to: &model)
    try await operation.run(on: &system)
    try assertEquivalent(model, system)
  }
}

public extension Strategy {
  /// Generates shrinkable model-testing operation sequences.
  static func operationSequences<Operation: Sendable>(
    of operation: Strategy<Operation>,
    length: ClosedRange<Int>
  ) -> Strategy<[Operation]> where Value == [Operation] {
    Strategy<Operation>.arrays(of: operation, length: length)
  }
}
