import XCTest
@testable import ConjectureXCTest

final class ConjectureXCTestIntegrationSmokeTests: XCTestCase {
  func testModuleImports() {
    XCTAssertEqual(ConjectureXCTestModule.name, "ConjectureXCTest")
  }
}
