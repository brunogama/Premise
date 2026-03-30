import PremiseCore

// MARK: - Precedence group

precedencegroup StrategyChoicePrecedence {
  associativity: left
  lowerThan: ComparisonPrecedence
  higherThan: LogicalConjunctionPrecedence
}

// MARK: - Operator declaration

/// Combines two strategies into a `oneOf` choice.
infix operator ||| : StrategyChoicePrecedence

// MARK: - Implementation

/// Combines two strategies into a `oneOf` choice.
///
/// This is syntactic sugar for ``Strategy/oneOf(_:)``.
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
  .oneOf([lhs, rhs])
}
