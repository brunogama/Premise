import Testing
import PremiseTesting
import PremiseStrategies

struct Money: Equatable {
  let cents: Int
  static let zero = Self(cents: 0)
  func add(_ other: Self) -> Self { Self(cents: cents + other.cents) }
}

let moneyStrategy = Strategy<Int>.integers(in: 0...100_000).map { Money(cents: $0) }

@Test func additionIsCommutative() async throws {
  try await forAll(moneyStrategy) { a in
    try await forAll(moneyStrategy) { b in
      #expect(a.add(b) == b.add(a))
    }
  }
}

@Test func additionIsAssociative() async throws {
  try await forAll(moneyStrategy) { a in
    try await forAll(moneyStrategy) { b in
      try await forAll(moneyStrategy) { c in
        #expect(a.add(b).add(c) == a.add(b.add(c)))
      }
    }
  }
}

@Test func zeroIsIdentityElement() async throws {
  try await forAll(moneyStrategy) { a in
    // Adding zero from either side must return the same value.
    #expect(a.add(.zero) == a)
    #expect(Money.zero.add(a) == a)
  }
}
