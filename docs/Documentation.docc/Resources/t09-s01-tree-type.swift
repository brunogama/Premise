import Testing
import PremiseTesting
import PremiseStrategies

// An arithmetic expression tree.
indirect enum Expr: Sendable, Equatable {
  case num(Int)
  case add(Self, Self)
  case mul(Self, Self)
  case neg(Self)
}
