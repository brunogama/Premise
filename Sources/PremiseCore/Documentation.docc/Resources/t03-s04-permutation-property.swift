import Testing
import PremiseTesting
import PremiseStrategies

func mySort(_ array: [Int]) -> [Int] { array.sorted() }
func isSorted(_ array: [Int]) -> Bool {
  guard array.count > 1 else { return true }
  return zip(array, array.dropFirst()).allSatisfy { $0 <= $1 }
}

let intArrays = Strategy<[Int]>.arrays(of: .integers(in: -500...500), length: 0...30)

@Test func sortedOutputIsOrdered() async throws {
  try await forAll(intArrays) { array in
    #expect(isSorted(mySort(array)))
  }
}

@Test func sortedOutputContainsSameElements() async throws {
  try await forAll(intArrays) { array in
    // Sorting both the original and the output and comparing confirms
    // that the same elements appear with the same frequency.
    // This catches bugs that drop, duplicate, or alter elements.
    #expect(array.sorted() == mySort(array))
  }
}
