import Testing
import PremiseTesting
import PremiseStrategies

// (exprStrategy and eval defined as above)

@Test func additionIsCommutative() async throws {
  // Generate two independent expressions using exprStrategy.
  try await forAll(exprStrategy) { left in
    try await forAll(exprStrategy) { right in
      // add(l, r) must evaluate to the same value as add(r, l).
      let forwardResult = eval(Expr.add(left, right))
      let reverseResult = eval(Expr.add(right, left))
      #expect(forwardResult == reverseResult)
    }
  }
}
