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
  case .num(let n): return n
  case .add(let l, let r): return eval(l) + eval(r)
  case .mul(let l, let r): return eval(l) * eval(r)
  case .neg(let e): return -eval(e)
  }
}
