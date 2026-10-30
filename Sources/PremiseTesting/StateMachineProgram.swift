/// A minimal printable program for a state-machine failure.
public struct StateMachineProgram:
  Sendable, Codable, Equatable, CustomStringConvertible
{
  /// Executed steps in order.
  public var steps: [StateMachineProgramStep]

  /// Creates a program containing the supplied steps.
  public init(steps: [StateMachineProgramStep] = []) {
    self.steps = steps
  }

  /// The program rendered as one step per line.
  public var description: String {
    guard !steps.isEmpty else { return "<empty program>" }
    return steps.map(\.description).joined(separator: "\n")
  }
}
