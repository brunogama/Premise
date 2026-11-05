import PremiseCore
struct AnyStrategyFactory: Sendable {
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
