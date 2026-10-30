import PremiseCore
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
  /// Combines the supplied strategies into a choice.
  public static func buildBlock(
    _ components: Strategy<Value>...
  ) -> Strategy<Value> {
    guard !components.isEmpty else {
      fatalError("StrategyBuilder requires at least one strategy")
    }
    if components.count == 1 { return components[0] }
    return .oneOf(components)
  }

  /// Passes through an optional strategy.
  public static func buildOptional(
    _ component: Strategy<Value>?
  ) -> Strategy<Value>? {
    component
  }

  /// Selects the first conditional branch.
  public static func buildEither(
    first component: Strategy<Value>
  ) -> Strategy<Value> {
    component
  }

  /// Selects the second conditional branch.
  public static func buildEither(
    second component: Strategy<Value>
  ) -> Strategy<Value> {
    component
  }

  /// Combines strategies produced by a loop.
  public static func buildArray(
    _ components: [Strategy<Value>]
  ) -> Strategy<Value> {
    guard !components.isEmpty else {
      fatalError("StrategyBuilder requires at least one strategy")
    }
    return .oneOf(components)
  }

  /// Passes through a strategy expression.
  public static func buildExpression(
    _ expression: Strategy<Value>
  ) -> Strategy<Value> {
    expression
  }
}
