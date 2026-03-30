import XCTest
import PremiseXCTest
import PremiseStrategies

final class SortTests: XCTestCase {
  private let intArrays = Strategy<[Int]>.arrays(
    of: .integers(in: -1000...1000),
    length: 0...50
  )

  func testSortedOutputIsOrdered() async throws {
    try await premise_forAll(intArrays) { array in
      let sorted = array.sorted()
      for i in 0..<(sorted.count - 1) {
        XCTAssertLessThanOrEqual(sorted[i], sorted[i + 1])
      }
    }
  }

  func testSortedOutputContainsSameElements() async throws {
    try await premise_forAll(intArrays) { array in
      let sorted = array.sorted()
      // Same multiset means the same frequency distribution.
      XCTAssertEqual(array.sorted(), sorted)
    }
  }
}
