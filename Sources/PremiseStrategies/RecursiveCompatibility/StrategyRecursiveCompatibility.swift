import PremiseCore

public extension Strategy {
  /// Convenience recursive strategy builder with explicit depth and size knobs.
  static func recursive(
    maxDepth: Int,
    desiredSize: Int = 4,
    expectedBranchSize: Int = 2,
    leaf: Strategy<Value>,
    _ build: @escaping @Sendable (Strategy<Value>) -> Strategy<Value>
  ) -> Strategy<Value> {
    recursive(
      RecursiveStrategyConfig(
        depth: maxDepth,
        desiredSize: desiredSize,
        expectedBranchSize: expectedBranchSize
      ),
      leaf: leaf,
      build
    )
  }
}
