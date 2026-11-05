import PremiseCore
// Preserve the public builder's existing struct type.
// swiftlint:disable convenience_type
/// A result builder that composes weighted strategies into a `frequency`
/// strategy.
///
/// ```swift
/// let biasedCoin: Strategy<Bool> = buildWeightedStrategy {
///     WeightedStrategy(weight: 3, .just(true))
///     WeightedStrategy(weight: 1, .just(false))
/// }
/// ```
@resultBuilder
public struct WeightedStrategyBuilder<Value: Sendable> {
  // swiftlint:enable convenience_type
  /// Combines weighted strategies into a frequency choice.
  public static func buildBlock(
    _ components: WeightedStrategy<Value>...
  ) -> Strategy<Value> {
    let pairs = components.map { ($0.weight, $0.strategy) }
    return .frequency(pairs)
  }

  /// Passes through a weighted strategy expression.
  public static func buildExpression(
    _ expression: WeightedStrategy<Value>
  ) -> WeightedStrategy<Value> {
    expression
  }
}
