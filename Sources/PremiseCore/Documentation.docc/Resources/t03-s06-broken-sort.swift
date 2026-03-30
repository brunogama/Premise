import Testing
import PremiseTesting
import PremiseStrategies

// Broken: drops the largest element when the array has more than 3 elements.
func mySort(_ array: [Int]) -> [Int] {
  var result = array.sorted()
  if result.count > 3 { result.removeLast() }
  return result
}

func isSorted(_ array: [Int]) -> Bool {
  guard array.count > 1 else { return true }
  return zip(array, array.dropFirst()).allSatisfy { $0 <= $1 }
}

let intArrays = Strategy<[Int]>.arrays(of: .integers(in: -500...500), length: 0...30)

@Test func sortedOutputIsOrdered() async throws {
  try await forAll(intArrays) { array in
    #expect(isSorted(mySort(array)))  // ← still passes (output is in order)
  }
}

@Test func sortedOutputContainsSameElements() async throws {
  try await forAll(intArrays) { array in
    #expect(array.sorted() == mySort(array))  // ← FAILS: missing element
  }
}

@Test func sortIsIdempotent() async throws {
  try await forAll(intArrays) { array in
    #expect(mySort(mySort(array)) == mySort(array))
  }
}
