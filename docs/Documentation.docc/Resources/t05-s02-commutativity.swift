import Testing
import PremiseTesting
import PremiseStrategies

struct Money: Equatable {
  let cents: Int
  static let zero = Self(cents: 0)
  func add(_ other: Self) -> Self { Self(cents: cents + other.cents) }
}

// Strategy for Money values in a realistic range.
let moneyStrategy = Strategy<Int>.integers(in: 0...100_000)
  .map { Money(cents: $0) }

@Test func additionIsCommutative() async throws {
  try await forAll(moneyStrategy) { a in
    try await forAll(moneyStrategy) { b in
      // a + b must equal b + a for all Money values.
      #expect(a.add(b) == b.add(a))
    }
  }
}
