/// A printable state-machine program step produced by a rule execution.
public struct StateMachineProgramStep:
  Sendable, Codable, Equatable, CustomStringConvertible
{
  /// Zero-based step index in the generated program.
  public let index: Int
  /// Name of the executed rule.
  public let ruleName: String
  /// Drawn argument rendered for diagnostics.
  public let argumentDescription: String
  /// Bundle outputs rendered for diagnostics.
  public let outputs: [String]

  /// Creates a printable step with its rule, argument, and outputs.
  public init(
    index: Int,
    ruleName: String,
    argumentDescription: String,
    outputs: [String] = []
  ) {
    self.index = index
    self.ruleName = ruleName
    self.argumentDescription = argumentDescription
    self.outputs = outputs
  }

  /// The step rendered as a rule invocation.
  public var description: String {
    let outputSuffix =
      outputs.isEmpty ? "" : " -> \(outputs.joined(separator: ", "))"
    return "\(index). \(ruleName)(\(argumentDescription))\(outputSuffix)"
  }
}
