/// Verbosity level for property execution diagnostics.
public enum PropertyVerbosity: String, Sendable, Codable, Hashable,
  CaseIterable
{
  case quiet
  case normal
  case verbose
  case debug
}
