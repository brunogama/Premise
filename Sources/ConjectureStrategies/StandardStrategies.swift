import ConjectureCore

public extension Strategy where Value == Int {
  /// Placeholder bounded integer strategy for the Phase 1 package contract.
  static func integers(in range: ClosedRange<Int>) -> Strategy<Int> {
    Strategy(label: "integers(in: \(range))") { _ in
      range.lowerBound
    }
  }
}
