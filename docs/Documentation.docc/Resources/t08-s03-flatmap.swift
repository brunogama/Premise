import Testing
import PremiseTesting
import PremiseStrategies

// Generate a pair (lower, upper) where lower <= upper, a valid range.
let validRange = Strategy<Int>.integers(in: 0...100)
  .flatMap { lower in
    Strategy<Int>.integers(in: lower...100)
      .map { upper in (lower, upper) }
  }

@Test func rangeIsAlwaysValid() async throws {
  try await forAll(validRange) { lower, upper in
    #expect(lower <= upper)
    // A ClosedRange with lower <= upper is always valid.
    let range = lower...upper
    #expect(range.contains(lower))
    #expect(range.contains(upper))
  }
}
