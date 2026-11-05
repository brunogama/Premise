import PremiseCore
import PremiseStrategies

indirect enum Expr: Sendable, Equatable {
  case num(Int)
  case add(Self, Self)
  case mul(Self, Self)
  case neg(Self)
}

let exprLeaf: Strategy<Expr> = Strategy<Int>.integers(in: -10...10)
  .map { .num($0) }

// The full recursive strategy.
// `build` receives a `smaller` strategy for one level less of nesting.
let exprStrategy = Strategy<Expr>.recursive(
  RecursiveStrategyConfig(
    depth: 4,  // max 4 levels of nesting
    desiredSize: 3,  // leaf weight = 3
    expectedBranchSize: 1  // branch weight = 1  → mostly shallow
  ),
  leaf: exprLeaf
) { smaller in
  // `smaller` generates sub-expressions one level shallower.
  Strategy<Expr>.oneOf([
    smaller.flatMap { left in smaller.map { right in Expr.add(left, right) } },
    smaller.flatMap { left in smaller.map { right in Expr.mul(left, right) } },
    smaller.map { expr in Expr.neg(expr) },
  ])
}
