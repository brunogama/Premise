/// Error thrown when a stateful command violates its declared expectation.
public struct StatefulCommandExpectationError: Error, Sendable,
  CustomStringConvertible
{
  /// Label for the command that violated its expectation.
  public let commandLabel: String

  /// Expected outcome that was violated.
  public let expectation: CommandExpectation

  /// Optional description of the error thrown by the command.
  public let underlyingDescription: String?

  /// Creates an expectation-violation error for a stateful command.
  public init(
    commandLabel: String,
    expectation: CommandExpectation,
    underlyingDescription: String? = nil
  ) {
    self.commandLabel = commandLabel
    self.expectation = expectation
    self.underlyingDescription = underlyingDescription
  }

  /// Human-readable diagnostic for the expectation violation.
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
