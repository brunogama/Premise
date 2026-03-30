import Testing
import PremiseTesting
import PremiseStrategies

struct Money: Equatable {
  let cents: Int
  static let zero = Self(cents: 0)

  // Buggy: overflows silently for large values.
  func add(_ other: Self) -> Self {
    let result = cents &+ other.cents  // wrapping add — intentional bug
    return Self(cents: result)
  }
}

let moneyStrategy = Strategy<Int>.integers(in: 0...Int.max / 2).map { Money(cents: $0) }
