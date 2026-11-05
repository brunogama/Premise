/// Errors produced while rendering ghostwriter templates.
public enum GhostwriterError:
  Error, Sendable, CustomStringConvertible, Equatable
{
  /// A required expression is missing or empty.
  case missingExpression(String)
  /// The requested template kind is not supported.
  case unsupportedKind(String)

  /// A human-readable explanation of the error.
  public var description: String {
    switch self {
    case .missingExpression(let name):
      return "Missing required ghostwriter expression: \(name)."
    case .unsupportedKind(let kind):
      return "Unsupported ghostwriter template kind: \(kind)."
    }
  }
}
