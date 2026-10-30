import Testing
import PremiseTesting
import PremiseStrategies

// A broken reverse: drops the last element for even-length arrays.
func myReverse<T>(_ array: [T]) -> [T] {
  guard array.count > 1 else { return array }
  var result = array
  if result.count % 2 == 0 {
    result.removeLast()  // Bug: drops an element
  }
  return result.reversed()
}

@Test func reversingTwiceIsIdentity() async throws {
  try await forAll(
    .arrays(of: .integers(in: 0...100), length: 0...20)
  ) { array in
    let reversed = myReverse(array)
    let twiceReversed = myReverse(reversed)
    #expect(twiceReversed == array)
  }
}
