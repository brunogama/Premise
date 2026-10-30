import XCTest
import PremiseCore
import PremiseXCTest
import PremiseStrategies

final class SortTests: XCTestCase {
  func testSortedOutputIsOrdered() async throws {
    let config = PropertyConfig(
      maxRuns: 500,  // generate 500 cases instead of the default 100
      seed: 42  // fixed seed for reproducible runs
    )
    try await premise_forAll(
      .arrays(of: .integers(in: -1000...1000), length: 0...50),
      config: config
    ) { array in
      let sorted = array.sorted()
      for i in 0..<(sorted.count - 1) {
        XCTAssertLessThanOrEqual(sorted[i], sorted[i + 1])
      }
    }
  }
}
