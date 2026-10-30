import PremiseStrategies

indirect enum Expr: Sendable, Equatable {
  case num(Int)
  case add(Self, Self)
  case mul(Self, Self)
  case neg(Self)
}

let exprLeaf: Strategy<Expr> = Strategy<Int>.integers(in: -10...10)
  .map { .num($0) }

// Shallow trees: many leaves, few branches.
let shallowExpr = Strategy<Expr>.recursive(
  RecursiveStrategyConfig(depth: 2, desiredSize: 8, expectedBranchSize: 1),
  leaf: exprLeaf
) { smaller in
  smaller.flatMap { left in smaller.map { right in Expr.add(left, right) } }
}

// Deep trees: more branches, fewer leaves.
let deepExpr = Strategy<Expr>.recursive(
  RecursiveStrategyConfig(depth: 6, desiredSize: 1, expectedBranchSize: 4),
  leaf: exprLeaf
) { smaller in
  Strategy<Expr>.oneOf([
    smaller.flatMap { left in smaller.map { right in Expr.add(left, right) } },
    smaller.flatMap { left in smaller.map { right in Expr.mul(left, right) } },
  ])
}
