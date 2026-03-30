/// Errors that a ``Strategy`` can throw during the value-generation phase.
///
/// The ``Runner`` distinguishes these errors from genuine property failures:
/// when a `StrategyError` escapes the draw phase the current run is silently
/// skipped rather than reported as a counterexample.  This preserves the
/// invariant that a failure must be caused by the *property under test*, not
/// by the inability of a strategy to satisfy its own constraints.
public enum StrategyError: Error, Sendable, CustomStringConvertible {
  /// A ``Strategy/filter(_:maxAttempts:)`` strategy could not produce a
  /// value satisfying the predicate within the allowed number of attempts.
  case filterExhausted(label: String, maxAttempts: Int)

  /// An ``Strategy/assume(_:maxAttempts:)`` guard failed to find a
  /// satisfying value within the allowed number of attempts.
  case assumptionFailed(label: String, maxAttempts: Int)

  public var description: String {
    switch self {
    case .filterExhausted(let label, let max):
      return """
        Strategy '\(label)' exhausted \(max) attempts \
        without satisfying the filter predicate. \
        Consider relaxing the filter or increasing maxAttempts.
        """

    case .assumptionFailed(let label, let max):
      return """
        Strategy '\(label)' failed assumption after \(max) attempts. \
        Consider widening the base strategy.
        """
    }
  }
}
