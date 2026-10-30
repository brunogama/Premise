import PremiseCore
/// A type that can derive its default property-testing strategy from a registry.
public protocol StrategyProviding: Sendable {
  static func premiseStrategy(in registry: StrategyRegistry) -> Strategy<Self>
}
