import Testing
import PremiseTesting
import PremiseStrategies

// Generate a pair (lo, hi) where lo <= hi — a valid range.
let validRange = Strategy<Int>.integers(in: 0...100)
  .flatMap { lo in
    Strategy<Int>.integers(in: lo...100)
      .map { hi in (lo, hi) }
  }

@Test func rangeIsAlwaysValid() async throws {
  try await forAll(validRange) { lo, hi in
    #expect(lo <= hi)
    // A ClosedRange with lo <= hi is always valid.
    let range = lo...hi
    #expect(range.contains(lo))
    #expect(range.contains(hi))
  }
}
