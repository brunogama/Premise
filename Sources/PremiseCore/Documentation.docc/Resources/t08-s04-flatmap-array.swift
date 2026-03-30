import Testing
import PremiseTesting
import PremiseStrategies

// Generate an array whose length is drawn first, so count is always exact.
let exactLengthArrays = Strategy<Int>.integers(in: 1...20)
  .flatMap { count in
    Strategy<[Int]>.arrays(
      of: .integers(in: 0...100),
      length: count...count  // exactly `count` elements
    ).map { array in (count, array) }
  }

@Test func arrayLengthMatchesDrawnCount() async throws {
  try await forAll(exactLengthArrays) { count, array in
    #expect(array.count == count)
  }
}
