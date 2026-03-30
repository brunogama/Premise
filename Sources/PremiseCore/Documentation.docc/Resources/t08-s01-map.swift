import Testing
import PremiseTesting
import PremiseStrategies

// Generate even integers by mapping: multiply each integer by 2.
let evenIntegers = Strategy<Int>.integers(in: 0...500)
  .map { $0 * 2 }

@Test func evenIntegersAreAlwaysEven() async throws {
  try await forAll(evenIntegers) { n in
    #expect(n % 2 == 0)
  }
}
