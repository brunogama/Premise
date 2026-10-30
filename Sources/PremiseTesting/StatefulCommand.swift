/// A model-vs-system command for stateful property tests.
public protocol StatefulCommand: Sendable {
  associatedtype Model: Sendable
  associatedtype System: Sendable

  /// Human-readable command label used in diagnostics.
  var label: String { get }

  /// Whether this command is expected to succeed or fail against the system.
  var expectation: CommandExpectation { get }

  /// Whether the command should run for the current model state.
  func canApply(to model: Model) -> Bool

  /// Applies the expected successful transition to the lightweight model.
  ///
  /// `Model` should be value-semantic. Implementations should only mutate this
  /// model argument and leave external state unchanged.
  func apply(to model: inout Model) throws

  /// Runs the command against the system under test.
  func run(on system: System) async throws
}

public extension StatefulCommand {
  var label: String { String(describing: Self.self) }
  var expectation: CommandExpectation { .succeeds }
}
