/// Policy for reporting more than one distinct failure in a single property run.
public enum MultipleBugReporting: String, Sendable, Codable, Hashable,
  CaseIterable
{
  /// Stop after the first failure.
  case first

  /// Collect all distinct failures when supported by the runner.
  case all
}
