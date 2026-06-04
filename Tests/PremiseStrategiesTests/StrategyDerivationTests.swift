import Testing

@testable import PremiseCore
@testable import PremiseStrategies

private struct UserID: Sendable, Equatable {
  let rawValue: Int
}

extension UserID: StrategyProviding {
  static func premiseStrategy(in registry: StrategyRegistry) -> Strategy<UserID> {
    registry.strategy(for: Int.self)
      .map { UserID(rawValue: $0) }
      .shrinking { id in
        id.rawValue == 0 ? [] : [UserID(rawValue: 0)]
      }
  }
}

@Test("Registry derives built-in strategies by type")
func registryDerivesBuiltIns() throws {
  let strategy = StrategyRegistry.standard.strategy(for: Int.self)
  var data = PremiseData(provider: PseudoRandomProvider(seed: 1, maxDraws: 100))
  let value = try strategy.draw(&data)
  #expect((-100...100).contains(value))
}

@Test("Registry derives custom StrategyProviding types")
func registryDerivesCustomTypes() throws {
  let strategy = StrategyRegistry.standard.strategy(for: UserID.self)
  var data = PremiseData(provider: PseudoRandomProvider(seed: 1, maxDraws: 100))
  let value = try strategy.draw(&data)
  #expect((-100...100).contains(value.rawValue))
}

@Test("Registry can be overridden without global mutable state")
func registryCanBeOverridden() throws {
  let registry = StrategyRegistry.standard.register(Int.self) { _ in .just(42) }
  let strategy = registry.strategy(for: Int.self)
  var data = PremiseData(provider: PseudoRandomProvider(seed: 1, maxDraws: 100))
  let value = try strategy.draw(&data)
  #expect(value == 42)
}
