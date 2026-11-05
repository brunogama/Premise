import Testing
import PremiseTesting
import PremiseStrategies

func mySort(_ array: [Int]) -> [Int] { array.sorted() }
func isSorted(_ array: [Int]) -> Bool {
  guard array.count > 1 else { return true }
  return zip(array, array.dropFirst()).allSatisfy { $0 <= $1 }
}

// Length 0...30 means the engine tries empty and single-element arrays
// (which always pass) alongside larger arrays (which exercise the logic).
// Edge-biased generation means 0 and 30 are tried with elevated frequency.
let intArrays = Strategy<[Int]>.arrays(
  of: .integers(in: -500...500),
  length: 0...30
)

@Test func sortedOutputIsOrdered() async throws {
  try await forAll(intArrays) { array in
    let sorted = mySort(array)
    #expect(isSorted(sorted), "mySort(\(array)) = \(sorted) is not sorted")
  }
}
