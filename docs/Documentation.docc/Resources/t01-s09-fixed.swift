import Testing
import PremiseTesting
import PremiseStrategies

// Fixed: no longer drops elements.
func myReverse<T>(_ array: [T]) -> [T] {
  Array(array.reversed())
}

@Test func reversingTwiceIsIdentity() async throws {
  try await forAll(
    .arrays(of: .integers(in: 0...100), length: 0...20)
  ) { array in
    // The stored trace [0, 0] is replayed first and now passes.
    // Then 99 fresh cases are generated and all pass.
    #expect(myReverse(myReverse(array)) == array)
  }
}
