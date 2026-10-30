/// Expected outcome for a stateful command.
public enum CommandExpectation: Sendable, Equatable {
  /// The command should update the model and system successfully.
  case succeeds

  /// The command should throw when run against the system and leave the model unchanged.
  case fails
}
