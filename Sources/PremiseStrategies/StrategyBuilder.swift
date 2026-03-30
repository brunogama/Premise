import PremiseCore

// MARK: - @StrategyBuilder result builder

/// A result builder that composes multiple strategies into a single
/// `oneOf` strategy, with optional support for `if`/`else` branches.
///
/// ```swift
/// let shape: Strategy<Shape> = buildStrategy {
///     Strategy.just(.circle(radius: 1))
///     Strategy.just(.square(side: 1))
///     if includeTriangles {
///         Strategy.just(.triangle(base: 1, height: 1))
///     }
/// }
/// ```
@resultBuilder
public struct StrategyBuilder<Value: Sendable> {
  public static func buildBlock(
    _ components: Strategy<Value>...
  ) -> Strategy<Value> {
    guard !components.isEmpty else {
      fatalError("StrategyBuilder requires at least one strategy")
    }
    if components.count == 1 { return components[0] }
    return .oneOf(components)
  }

  public static func buildOptional(
    _ component: Strategy<Value>?
  ) -> Strategy<Value>? {
    component
  }

  public static func buildEither(
    first component: Strategy<Value>
  ) -> Strategy<Value> {
    component
  }

  public static func buildEither(
    second component: Strategy<Value>
  ) -> Strategy<Value> {
    component
  }

  public static func buildArray(
    _ components: [Strategy<Value>]
  ) -> Strategy<Value> {
    guard !components.isEmpty else {
      fatalError("StrategyBuilder requires at least one strategy")
    }
    return .oneOf(components)
  }

  public static func buildExpression(
    _ expression: Strategy<Value>
  ) -> Strategy<Value> {
    expression
  }
}

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

/// A strategy annotated with a weight for use in ``buildWeightedStrategy``.
public struct WeightedStrategy<Value: Sendable>: Sendable {
  public let weight: Int
  public let strategy: Strategy<Value>

  public init(weight: Int, _ strategy: Strategy<Value>) {
    self.weight = weight
    self.strategy = strategy
  }
}

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
  public static func buildBlock(
    _ components: WeightedStrategy<Value>...
  ) -> Strategy<Value> {
    let pairs = components.map { ($0.weight, $0.strategy) }
    return .frequency(pairs)
  }

  public static func buildExpression(
    _ expression: WeightedStrategy<Value>
  ) -> WeightedStrategy<Value> {
    expression
  }
}

public func buildWeightedStrategy<Value: Sendable>(
  @WeightedStrategyBuilder<Value> _ build: () -> Strategy<Value>
) -> Strategy<Value> {
  build()
}
