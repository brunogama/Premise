import Testing

@testable import PremiseCore
@testable import PremiseStrategies

private enum List: Sendable, Equatable {
  case end
  indirect case node(Int, Self)
}

private typealias ListStrategy = Strategy<List>

@Test("recursive strategy respects the configured depth")
func recursiveStrategyRespectsConfiguredDepth() throws {
  let strategy = ListStrategy.recursive(
    .init(depth: 3, desiredSize: 1, expectedBranchSize: 1),
    leaf: .just(.end)
  ) { recursive in
    recursive.map { .node(1, $0) }
  }

  var data = PremiseData(provider: PseudoRandomProvider(seed: 16, maxDraws: 8))
  let value = try strategy.draw(&data)
  #expect(depth(of: value) <= 3)
}

private func depth(of list: List) -> Int {
  switch list {
  case .end:
    return 0

  case .node(_, let next):
    return 1 + depth(of: next)
  }
}
