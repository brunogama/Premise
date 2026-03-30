import XCTest
@testable import PremiseXCTest

final class PremiseXCTestIntegrationSmokeTests: XCTestCase {
  func testModuleImports() {
    XCTAssertEqual(PremiseXCTestModule.name, "PremiseXCTest")
  }
}
