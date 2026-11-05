import PremiseCore

// MARK: - Free function entry point

/// Builds a strategy using the ``StrategyBuilder`` result builder.
///
/// ```swift
/// let intOrString: Strategy<String> = buildStrategy {
///     Strategy<String>.ascii
///     Strategy<Int>.integers(in: 0...100).map(String.init)
/// }
/// ```
public func buildStrategy<Value: Sendable>(
  @StrategyBuilder<Value> _ build: () -> Strategy<Value>
) -> Strategy<Value> {
  build()
}

// MARK: - Weighted builder

/// A strategy annotated with a weight for use in ``/PremiseStrategies/buildWeightedStrategy(_:)``.
public struct WeightedStrategy<Value: Sendable>: Sendable {
  /// Relative selection weight.
  public let weight: Int
  /// Strategy selected when this weight is chosen.
  public let strategy: Strategy<Value>

  /// Creates a weighted strategy.
  public init(weight: Int, _ strategy: Strategy<Value>) {
    self.weight = weight
    self.strategy = strategy
  }
}

/// Builds a frequency strategy from weighted strategy expressions.
public func buildWeightedStrategy<Value: Sendable>(
  @WeightedStrategyBuilder<Value> _ build: () -> Strategy<Value>
) -> Strategy<Value> {
  build()
}
