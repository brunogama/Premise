import Testing
import PremiseTesting
import PremiseStrategies

// A simple money type that stores amounts in cents.
struct Money: Equatable, CustomStringConvertible {
  let cents: Int
  static let zero = Self(cents: 0)

  func add(_ other: Self) -> Self {
    Self(cents: cents + other.cents)
  }

  var description: String { "\(cents)¢" }
}
