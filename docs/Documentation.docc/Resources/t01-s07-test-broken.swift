import Testing
import PremiseTesting
import PremiseStrategies

func myReverse<T>(_ array: [T]) -> [T] {
  guard array.count > 1 else { return array }
  var result = array
  if result.count % 2 == 0 { result.removeLast() }
  return result.reversed()
}

// The property is the same; we just point it at myReverse.
@Test func reversingTwiceIsIdentity() async throws {
  try await forAll(
    .arrays(of: .integers(in: 0...100), length: 0...20)
  ) { array in
    #expect(myReverse(myReverse(array)) == array)
  }
}
