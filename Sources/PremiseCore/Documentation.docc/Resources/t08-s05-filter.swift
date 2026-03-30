import Testing
import PremiseTesting
import PremiseStrategies

// Filter to odd numbers. About half of all values pass, so this is fine.
let oddNumbers = Strategy<Int>.integers(in: 1...99)
  .filter { $0 % 2 != 0 }

@Test
func oddNumbersAreNeverDivisibleByTwo() async throws {
  try await forAll(oddNumbers) { n in
    #expect(n % 2 != 0)
  }
}
