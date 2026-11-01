import PremiseCore
// A free operator preserves existing lookup and overload resolution.
// swiftlint:disable static_operator
/// Combines two strategies into a `oneOf` choice.
///
/// This is syntactic sugar for ``/PremiseCore/Strategy/oneOf(_:)``.
///
/// ```swift
/// let digit: Strategy<Character> = .digit
/// let letter: Strategy<Character> = .letter
/// let alphanumeric = digit ||| letter
/// ```
///
/// Chains associate left-to-right:
/// ```swift
/// let any = digit ||| letter ||| .ascii
/// ```
public func ||| <Value: Sendable>(
  lhs: Strategy<Value>,
  rhs: Strategy<Value>
) -> Strategy<Value> {
  // swiftlint:enable static_operator
  .oneOf([lhs, rhs])
}
