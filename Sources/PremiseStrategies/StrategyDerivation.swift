import Foundation
import PremiseCore

/// A type that can derive its default property-testing strategy from a registry.
public protocol StrategyProviding: Sendable {
  static func premiseStrategy(in registry: StrategyRegistry) -> Strategy<Self>
}

/// Immutable registry for deriving strategies by value type.
public struct StrategyRegistry: Sendable {
  private let entries: [ObjectIdentifier: AnyStrategyFactory]

  /// Creates an empty strategy registry.
  public init() {
    entries = [:]
  }

  private init(entries: [ObjectIdentifier: AnyStrategyFactory]) {
    self.entries = entries
  }

  /// Standard strategies for common Swift and Foundation value types.
  public static let standard = StrategyRegistry()
    .register(Int.self, strategy: Strategy<Int>.integers(in: -100...100))
    .register(Bool.self, strategy: Strategy<Bool>.booleans)
    .register(String.self, strategy: Strategy<String>.ascii)
    .register(Double.self, strategy: Strategy<Double>.floats(in: -100...100))
    .register(UUID.self, strategy: Strategy<UUID>.any)

  /// Returns a copy of the registry with `strategy` scoped to `type`.
  public func register<Value: Sendable>(
    _ type: Value.Type,
    strategy: Strategy<Value>
  ) -> StrategyRegistry {
    register(type) { _ in strategy }
  }

  /// Returns a copy of the registry with a scoped factory for `type`.
  public func register<Value: Sendable>(
    _ type: Value.Type,
    _ makeStrategy: @escaping @Sendable (StrategyRegistry) -> Strategy<Value>
  ) -> StrategyRegistry {
    var entries = entries
    entries[ObjectIdentifier(type)] = AnyStrategyFactory(makeStrategy)
    return StrategyRegistry(entries: entries)
  }

  /// Resolves a registered strategy, or derives one from the value type.
  public func strategy<Value: StrategyProviding>(
    for type: Value.Type
  ) -> Strategy<Value> {
    strategyIfRegistered(for: type) ?? Value.premiseStrategy(in: self)
  }

  /// Resolves a registered strategy for `type`.
  public func strategy<Value: Sendable>(
    for type: Value.Type
  ) -> Strategy<Value> {
    guard let strategy = strategyIfRegistered(for: type) else {
      preconditionFailure("No strategy registered for \(type)")
    }
    return strategy
  }

  private func strategyIfRegistered<Value: Sendable>(
    for type: Value.Type
  ) -> Strategy<Value>? {
    entries[ObjectIdentifier(type)]?.strategy(for: type, in: self)
  }
}

private struct AnyStrategyFactory: Sendable {
  private let make: @Sendable (StrategyRegistry) -> any Sendable

  init<Value: Sendable>(
    _ make: @escaping @Sendable (StrategyRegistry) -> Strategy<Value>
  ) {
    self.make = { registry in make(registry) }
  }

  func strategy<Value: Sendable>(
    for _: Value.Type,
    in registry: StrategyRegistry
  ) -> Strategy<Value>? {
    make(registry) as? Strategy<Value>
  }
}
