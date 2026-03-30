import XCTest

@testable import ConjectureCore
@testable import ConjectureXCTest

final class ConjectureForAllIntegrationTests: XCTestCase {

    func testPassingProperty() async throws {
        let strategy = Strategy<Int>.integers(in: 1...10)
        try await conjecture_forAll(strategy) { value in
            XCTAssertGreaterThanOrEqual(value, 1)
            XCTAssertLessThanOrEqual(value, 10)
        }
    }

    func testPassingPropertyWithCustomConfig() async throws {
        let strategy = Strategy<Int>.integers(in: 0...100)
        let config = PropertyConfig(maxRuns: 10, seed: 42)
        try await conjecture_forAll(strategy, config: config) { value in
            XCTAssertGreaterThanOrEqual(value, 0)
        }
    }

    func testFailingPropertyReportsFailure() async throws {
        // The integers strategy returns lowerBound (1), so checking > 5 fails.
        // We verify the adapter produces a failure message by using
        // XCTExpectFailure to capture the expected XCTFail call.
        let strategy = Strategy<Int>.integers(in: 1...10)

        XCTExpectFailure("conjecture_forAll should report a counterexample") {
            $0.compactDescription.contains("Counterexample")
        }

        try await conjecture_forAll(strategy) { value in
            guard value > 5 else {
                throw ConjectureTestError(message: "value \(value) is not > 5")
            }
        }
    }

    func testFailureMessageContainsReplayInstructions() async throws {
        let strategy = Strategy<Int>.integers(in: 0...100)

        XCTExpectFailure("conjecture_forAll should include replay instructions") {
            $0.compactDescription.contains("Replay")
        }

        try await conjecture_forAll(strategy) { _ in
            throw ConjectureTestError(message: "always fails")
        }
    }
}

/// A simple error type for testing property failures.
private struct ConjectureTestError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}
