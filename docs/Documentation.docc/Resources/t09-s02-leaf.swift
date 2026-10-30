import PremiseCore
import PremiseStrategies

indirect enum Expr: Sendable, Equatable {
  case num(Int)
  case add(Self, Self)
  case mul(Self, Self)
  case neg(Self)
}

// The leaf strategy: produces only .num(n) — no recursion.
let exprLeaf: Strategy<Expr> = Strategy<Int>.integers(in: -10...10)
  .map { .num($0) }
