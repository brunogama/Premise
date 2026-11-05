import PremiseCore

/// A per-run collection of values produced by one rule and consumed by others.
public struct StateMachineBundle<Element: Sendable>: Sendable {
  /// Human-readable bundle name used in strategy labels.
  public let label: String
  let key: StateMachineBundleKey

  /// Creates a bundle whose values are scoped to a single generated example.
  public init(_ label: String) {
    self.label = label
    key = StateMachineBundleKey(token: StateMachineBundleToken(label: label))
  }

  /// Returns a strategy that draws from values saved in the current run.
  public func strategy() -> Strategy<Element> {
    strategy(consuming: false)
  }

  /// Returns a strategy that draws and removes a saved bundle value.
  public func consumingStrategy() -> Strategy<Element> {
    strategy(consuming: true)
  }

  /// Returns a bundle strategy, optionally consuming selected values.
  public func strategy(consuming: Bool) -> Strategy<Element> {
    let key = key
    let label = label
    return Strategy<Element>(
      label: consuming ? "stateMachineBundle(\(label), consuming)" : "stateMachineBundle(\(label))",
      draw: { data in
        guard let context = StateMachineBundleScope.current else {
          throw StrategyError.assumptionFailed(label: label, maxAttempts: 1)
        }

        guard
          let value: Element = context.selectValue(
            for: key,
            consuming: consuming,
            using: &data
          )
        else {
          throw StrategyError.assumptionFailed(label: label, maxAttempts: 1)
        }
        return value
      }
    )
  }
}
