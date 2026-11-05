/// A reduced rational-number value used by Premise's numeric strategies.
public struct PremiseRational:
  Sendable, Codable, Equatable, Hashable, CustomStringConvertible
{
  /// Reduced signed numerator.
  public let numerator: Int

  /// Positive reduced denominator.
  public let denominator: Int

  /// Creates a reduced rational value from a numerator and non-zero denominator.
  public init(numerator: Int, denominator: Int) {
    precondition(
      denominator != 0,
      "PremiseRational denominator must be non-zero"
    )
    let sign = denominator < 0 ? -1 : 1
    let divisor = greatestCommonDivisor(
      absClamped(numerator),
      absClamped(denominator)
    )
    self.numerator = sign * (numerator / divisor)
    self.denominator = absClamped(denominator) / divisor
  }

  /// Textual `numerator/denominator` representation.
  public var description: String { "\(numerator)/\(denominator)" }
}
private func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
  var a = max(1, lhs)
  var b = max(1, rhs)
  while b != 0 {
    let remainder = a % b
    a = b
    b = remainder
  }
  return max(1, a)
}

private func absClamped(_ value: Int) -> Int {
  value == Int.min ? Int.max : abs(value)
}
