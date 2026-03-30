import Testing
import PremiseTesting
import PremiseStrategies

// (exprStrategy, exprLeaf, eval defined as above)

@Test func multiplicationDistributesOverAddition() async throws {
  // a * (b + c) == a*b + a*c
  try await forAll(exprLeaf) { a in  // use leaf to keep numbers small
    try await forAll(exprLeaf) { b in
      try await forAll(exprLeaf) { c in
        let lhs = eval(.mul(a, .add(b, c)))
        let rhs = eval(.add(.mul(a, b), .mul(a, c)))
        #expect(lhs == rhs, "a=\(eval(a)) b=\(eval(b)) c=\(eval(c)): \(lhs) ≠ \(rhs)")
      }
    }
  }
}
