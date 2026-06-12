/// Expected outcome for a stateful command.
public enum CommandExpectation: Sendable, Equatable {
  /// The command should update the model and system successfully.
  case succeeds

  /// The command should throw when run against the system and leave the model unchanged.
  case fails
}

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
  func apply(to model: inout Model) throws

  /// Runs the command against the system under test.
  func run(on system: System) async throws
}

public extension StatefulCommand {
  var label: String { String(describing: Self.self) }
  var expectation: CommandExpectation { .succeeds }
}

/// Error thrown when a stateful command violates its declared expectation.
public struct StatefulCommandExpectationError: Error, Sendable, CustomStringConvertible {
  public let commandLabel: String
  public let expectation: CommandExpectation
  public let underlyingDescription: String?

  public init(
    commandLabel: String,
    expectation: CommandExpectation,
    underlyingDescription: String? = nil
  ) {
    self.commandLabel = commandLabel
    self.expectation = expectation
    self.underlyingDescription = underlyingDescription
  }

  public var description: String {
    switch expectation {
    case .succeeds:
      let suffix = underlyingDescription.map { ": \($0)" } ?? ""
      return "Command \(commandLabel) was expected to succeed but failed\(suffix)"
    case .fails:
      return "Command \(commandLabel) was expected to fail but succeeded"
    }
  }
}

/// Runs stateful commands against a lightweight model and a system under test.
public func checkStateMachine<Command: StatefulCommand>(
  commands: [Command],
  initialModel: Command.Model,
  makeSystem: @escaping @Sendable () async throws -> Command.System,
  assertEquivalent: @escaping @Sendable (Command.Model, Command.System) async throws -> Void
) async throws {
  var model = initialModel
  let system = try await makeSystem()
  try await assertEquivalent(model, system)

  for command in commands where command.canApply(to: model) {
    switch command.expectation {
    case .succeeds:
      try command.apply(to: &model)
      do {
        try await command.run(on: system)
      } catch {
        throw StatefulCommandExpectationError(
          commandLabel: command.label,
          expectation: .succeeds,
          underlyingDescription: String(describing: error)
        )
      }
      try await assertEquivalent(model, system)

    case .fails:
      do {
        try await command.run(on: system)
      } catch {
        try await assertEquivalent(model, system)
        continue
      }
      throw StatefulCommandExpectationError(
        commandLabel: command.label,
        expectation: .fails
      )
    }
  }
}
