// MARK: - Precedence group

precedencegroup StrategyChoicePrecedence {
  associativity: left
  lowerThan: ComparisonPrecedence
  higherThan: LogicalConjunctionPrecedence
}

// MARK: - Operator declaration

/// Combines two strategies into a `oneOf` choice.
infix operator ||| : StrategyChoicePrecedence
