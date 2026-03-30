import PremiseCore

/// Protocol for stateless coverage scoring.
///
/// A coverage guide evaluates a single-run coverage snapshot against a
/// cumulative baseline and reports how many new edges were discovered.
/// Guides are purely observational sidecar components -- they MUST NOT
/// mutate trace content or affect replay semantics.
public protocol CoverageGuide: Sendable {
  /// Evaluates a coverage snapshot against a known baseline.
  ///
  /// - Parameters:
  ///   - snapshot: The coverage map observed during this execution.
  ///   - baseline: The cumulative coverage map of all prior executions.
  ///   - trace: The choice trace that produced this execution.
  /// - Returns: A score indicating how interesting this input is.
  ///   Higher scores indicate more novel coverage.
  func score(
    snapshot: CoverageMap,
    baseline: CoverageMap,
    trace: ChoiceTrace
  ) -> CoverageScore
}

/// A coverage interestingness score.
///
/// Higher values indicate more novel coverage discovery. A score of zero
/// means no new edges were discovered.
public struct CoverageScore: Sendable, Comparable, Equatable {
  /// The raw numeric score value.
  public let value: Int

  /// A score indicating no new coverage was discovered.
  public static let zero = Self(value: 0)

  /// Creates a coverage score with the given value.
  ///
  /// - Parameter value: The numeric score. Negative values are clamped to zero.
  public init(value: Int) {
    self.value = max(0, value)
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.value < rhs.value
  }
}
