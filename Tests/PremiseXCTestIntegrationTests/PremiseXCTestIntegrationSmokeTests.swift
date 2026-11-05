import XCTest
@testable import PremiseXCTest

// XCTest integration requires XCTestCase inheritance.
// swiftlint:disable:next prefer_struct
final class PremiseXCTestIntegrationSmokeTests: XCTestCase {
  func testModuleImports() {
    XCTAssertEqual(PremiseXCTestModule.name, "PremiseXCTest")
  }
}
