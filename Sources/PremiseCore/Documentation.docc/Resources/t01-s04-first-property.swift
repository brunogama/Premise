import Testing
import PremiseTesting
import PremiseStrategies

@Test func reversingTwiceIsIdentity() async throws {
  // The engine generates up to 100 random integer arrays,
  // each with 0 to 20 elements drawn from 0...100.
  try await forAll(
    .arrays(of: .integers(in: 0...100), length: 0...20)
  ) { array in
    let reversed = Array(array.reversed())
    let twiceReversed = Array(reversed.reversed())
    #expect(twiceReversed == array)
  }
}
