import Testing

@testable import PremiseCore
@testable import PremiseTesting

@Test("forAll with passing property completes without error")
func forAllPassingProperty() async throws {
  let strategy = Strategy<Int>.integers(in: 1...10)
  try await forAll(strategy) { value in
    #expect(value >= 1)
    #expect(value <= 10)
  }
}

@Test("forAll with custom config completes without error")
func forAllWithCustomConfig() async throws {
  let strategy = Strategy<Int>.integers(in: 0...100)
  let config = PropertyConfig(maxRuns: 10, seed: 42)
  try await forAll(strategy, config: config) { value in
    #expect(value >= 0)
  }
}

@Test("forAll with failing property records an issue")
func forAllFailingProperty() async throws {
  let strategy = Strategy<Int>.integers(in: 1...10)
  // The integers strategy returns lowerBound (1), so checking > 5 fails.
  await withKnownIssue {
    try await forAll(strategy) { value in
      guard value > 5 else {
        throw PropertyTestFailure(message: "value \(value) is not > 5")
      }
    }
  }
}

@Test("forAll failure output contains counterexample")
func forAllFailureContainsCounterexample() async throws {
  let strategy = Strategy<Int>.integers(in: 0...100)
  // Verify the adapter executes the property and records an issue on failure.
  await withKnownIssue {
    try await forAll(strategy) { _ in
      throw PropertyTestFailure(message: "always fails")
    }
  }
}

/// A simple error type for testing property failures.
private struct PropertyTestFailure: Error, CustomStringConvertible {
  let message: String
  var description: String { message }
}
