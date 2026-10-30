import PremiseStrategies

indirect enum Expr: Sendable, Equatable {
  case num(Int)
  case add(Self, Self)
  case mul(Self, Self)
  case neg(Self)
}

// A straightforward recursive evaluator.
func eval(_ expr: Expr) -> Int {
  switch expr {
  case .num(let number): return number
  case .add(let left, let right): return eval(left) + eval(right)
  case .mul(let left, let right): return eval(left) * eval(right)
  case .neg(let nested): return -eval(nested)
  }
}
