import Foundation
import PremiseCore


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
  public static let standard = Self()
    .register(Int.self, strategy: Strategy<Int>.integers(in: -100...100))
    .register(Bool.self, strategy: Strategy<Bool>.booleans)
    .register(String.self, strategy: Strategy<String>.ascii)
    .register(Double.self, strategy: Strategy<Double>.floats(in: -100...100))
    .register(UUID.self, strategy: Strategy<UUID>.any)

  /// Returns a copy of the registry with `strategy` scoped to `type`.
  public func register<Value: Sendable>(
    _ type: Value.Type,
    strategy: Strategy<Value>
  ) -> Self {
    register(type) { _ in strategy }
  }

  /// Returns a copy of the registry with a scoped factory for `type`.
  public func register<Value: Sendable>(
    _ type: Value.Type,
    _ makeStrategy: @escaping @Sendable (Self) -> Strategy<Value>
  ) -> Self {
    var entries = entries
    entries[ObjectIdentifier(type)] = AnyStrategyFactory(makeStrategy)
    return Self(entries: entries)
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
