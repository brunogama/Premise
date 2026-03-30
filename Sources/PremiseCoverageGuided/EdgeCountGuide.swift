import PremiseCore

/// A simple coverage guide that scores inputs by counting newly discovered edges.
///
/// ``EdgeCountGuide`` is stateless: it compares a single-run snapshot against
/// a provided baseline and returns the count of novel edges as the score.
/// Cumulative state management is handled by the caller (typically
/// ``CoverageTracker``).
public struct EdgeCountGuide: CoverageGuide {
  /// Creates an edge-count guide.
  public init() {}

  /// Scores a coverage snapshot by counting edges present in `snapshot`
  /// but absent from `baseline`.
  ///
  /// - Parameters:
  ///   - snapshot: The coverage observed during a single property execution.
  ///   - baseline: The cumulative coverage map of all prior executions.
  ///   - trace: The choice trace that produced this execution (unused).
  /// - Returns: A score equal to the number of newly discovered edges.
  public func score(
    snapshot: CoverageMap,
    baseline: CoverageMap,
    trace: ChoiceTrace
  ) -> CoverageScore {
    let novel = baseline.newEdges(comparedTo: snapshot)
    return CoverageScore(value: novel.count)
  }
}
