import XCTest
import PremiseXCTest
import PremiseStrategies

final class SortTests: XCTestCase {
  func testSortedOutputIsOrdered() async throws {
    try await premise_forAll(
      .arrays(of: .integers(in: -1000...1000), length: 0...50)
    ) { array in
      let sorted = array.sorted()
      for i in 0..<(sorted.count - 1) {
        XCTAssertLessThanOrEqual(
          sorted[i],
          sorted[i + 1],
          "Element at \(i) must be ≤ element at \(i + 1)"
        )
      }
    }
  }
}
