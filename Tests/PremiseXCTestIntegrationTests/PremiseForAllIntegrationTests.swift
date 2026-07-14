import XCTest

@testable import PremiseCore
@testable import PremiseXCTest

final class PremiseForAllIntegrationTests: XCTestCase {

  func testPassingProperty() async throws {
    let strategy = Strategy<Int>.integers(in: 1...10)
    try await premise_forAll(strategy) { value in
      XCTAssertGreaterThanOrEqual(value, 1)
      XCTAssertLessThanOrEqual(value, 10)
    }
  }

  func testPassingPropertyWithCustomConfig() async throws {
    let strategy = Strategy<Int>.integers(in: 0...100)
    let config = PropertyConfig(maxRuns: 10, seed: 42)
    try await premise_forAll(strategy, config: config) { value in
      XCTAssertGreaterThanOrEqual(value, 0)
    }
  }

  // XCTExpectFailure exists only in Apple's XCTest; swift-corelibs-xctest on
  // Linux has no failure-expectation API, so these three checks are
  // Darwin-only.
  #if canImport(Darwin)
  func testFailingPropertyReportsFailure() async throws {
    // The integers strategy returns lowerBound (1), so checking > 5 fails.
    // We verify the adapter produces a failure message by using
    // XCTExpectFailure to capture the expected XCTFail call.
    let strategy = Strategy<Int>.integers(in: 1...10)

    XCTExpectFailure("premise_forAll should report a counterexample") {
      $0.compactDescription.contains("Minimal counterexample")
    }

    try await premise_forAll(strategy, config: isolatedFailureStorage()) { value in
      guard value > 5 else {
        throw PremiseTestError(message: "value \(value) is not > 5")
      }
    }
  }

  func testFailureMessageContainsReplayInstructions() async throws {
    let strategy = Strategy<Int>.integers(in: 0...100)

    XCTExpectFailure("premise_forAll should include replay instructions") {
      $0.compactDescription.contains("Replay")
    }

    try await premise_forAll(strategy, config: isolatedFailureStorage()) { _ in
      throw PremiseTestError(message: "always fails")
    }
  }

  func testRunsExplicitExamplesBeforeGeneration() async throws {
    XCTExpectFailure("premise_forAll should report explicit example failures") {
      $0.compactDescription.contains("explicit example failed")
    }

    try await premise_forAll(
      Strategy<Int>.just(99),
      config: isolatedFailureStorage(PropertyConfig(maxRuns: 10, seed: 1).phases([.explicit])),
      explicitExamples: [3]
    ) { value in
      if value == 3 {
        throw PremiseTestError(message: "explicit example failed")
      }
    }
  }
  #endif

  func testAcceptsExpectedFailingExplicitExamples() async throws {
    try await premise_forAll(
      Strategy<Int>.just(99),
      config: PropertyConfig(maxRuns: 10, seed: 1).phases([.explicit]),
      examples: [.xfail(3, reason: "known bad input")]
    ) { value in
      if value == 3 {
        throw PremiseTestError(message: "explicit example failed as expected")
      }
    }
  }
}

/// A simple error type for testing property failures.
private struct PremiseTestError: Error, CustomStringConvertible {
  let message: String
  var description: String { message }
}
