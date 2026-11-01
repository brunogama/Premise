import PremiseCore

public extension Strategy {
  // Preserve the public parameter order and trailing-closure call sites.
  // swiftlint:disable function_default_parameter_at_end
  // swiftlint:disable function_parameter_count
  /// Convenience recursive strategy builder with explicit depth and size knobs.
  static func recursive(
    maxDepth: Int,
    desiredSize: Int = 4,
    expectedBranchSize: Int = 2,
    leaf: Strategy<Value>,
    _ build: @escaping @Sendable (Strategy<Value>) -> Strategy<Value>
  ) -> Strategy<Value> {
    // swiftlint:enable function_default_parameter_at_end function_parameter_count
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
