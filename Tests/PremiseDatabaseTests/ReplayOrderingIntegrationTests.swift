import PremiseCore
import PremiseDatabase
import Foundation
import Testing

/// Integration tests proving replay-first ordering through the persistence
/// boundary.
///
/// These tests exercise ``ReplayFirstExecutor`` end-to-end against a real
/// ``FileBackedDatabase`` to verify that persisted traces are replayed before
/// fresh generation and that failures are written back to disk.
@Suite("ReplayFirstExecutor integration")
struct ReplayOrderingIntegrationTests {

  // MARK: - Helpers

  /// Creates a unique temporary directory for test isolation.
  private func makeTempDirectory() throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: tempDir,
      withIntermediateDirectories: true
    )
    return tempDir
  }

  /// Builds a ``PropertyIdentity`` for testing.
  private func makePropertyID(
    fileID: String = "ReplayTest.swift",
    line: UInt = 10,
    strategyLabel: String = "testInt"
  ) -> PropertyIdentity {
    PropertyIdentity(
      fileID: fileID,
      line: line,
      strategyLabel: strategyLabel
    )
  }

  /// A simple integer strategy that draws a single integer from a
  /// closed range, suitable for deterministic trace replay.
  private func integerStrategy(
    in range: ClosedRange<Int>
  ) -> Strategy<Int> {
    Strategy<Int>(label: "testInt") { data in
      data.drawInteger(in: range)
    }
  }

  private func makeExecutor(
    _ database: FileBackedDatabase,
    for propertyID: PropertyIdentity,
    maxRuns: Int
  ) -> ReplayFirstExecutor<Int> {
    let config = PropertyConfig(maxRuns: maxRuns, seed: 0, replayEnabled: true)
    let runner = Runner(
      strategy: integerStrategy(in: 0...100),
      config: config,
      propertyID: propertyID
    )
    return ReplayFirstExecutor(runner: runner, database: database)
  }

  // MARK: - Tests

  @Test("Persisted trace replays before fresh generation when maxRuns is 0")
  func replayBeforeFreshWithZeroMaxRuns() async throws {
    let database = FileBackedDatabase(rootDirectory: try makeTempDirectory())
    let propertyID = makePropertyID()

    // Persist the failure record manually so it exists before execution.
    try await database.save(
      FailureRecord(
        propertyID: propertyID,
        trace: ChoiceTrace(entries: [.integer(5)]),
        errorMessage: "value was 5"
      )
    )

    // Configure runner with maxRuns: 0 so no fresh generation occurs.
    // The only way a failure can surface is through replay.
    let executor = makeExecutor(database, for: propertyID, maxRuns: 0)
    let result = try await executor.execute { value in
      if value == 5 {
        throw PropertyFailure(message: "value was 5")
      }
    }

    // The only way to get a failure with maxRuns: 0 is via replay.
    guard case .failure(let record, value: _) = result else {
      Issue.record("Expected failure from replay but got passed")
      return
    }
    #expect(record.errorMessage.contains("value was 5"))
  }

  @Test("Failure results are persisted and visible in subsequent loadTraces")
  func failurePersistenceRoundTrip() async throws {
    let tempDir = try makeTempDirectory()
    let database = FileBackedDatabase(rootDirectory: tempDir)
    let propertyID = makePropertyID(
      fileID: "Persistence.swift",
      line: 20
    )

    // No existing traces: start fresh. The runner will do fresh
    // generation and find a failure, which the executor must persist.
    let executor = makeExecutor(database, for: propertyID, maxRuns: 10)

    // Property that always fails: guarantees a failure record.
    let result = try await executor.execute { _ in
      throw PropertyFailure(message: "always fails")
    }

    guard case .failure = result else {
      Issue.record("Expected failure but got passed")
      return
    }

    // Verify the failure was persisted back to the database.
    let traces = try await database.loadTraces(for: propertyID)
    #expect(traces.count == 1)
    #expect(traces[0].entries.isEmpty == false)
  }

  @Test("Passing replay does not persist a new record")
  func passingReplayDoesNotPersist() async throws {
    let tempDir = try makeTempDirectory()
    let database = FileBackedDatabase(rootDirectory: tempDir)
    let propertyID = makePropertyID(fileID: "PassTest.swift", line: 30)

    // Seed a trace that draws 3, then run a property that accepts all.
    try await database.save(
      FailureRecord(
        propertyID: propertyID,
        trace: ChoiceTrace(entries: [.integer(3)]),
        errorMessage: "prior failure"
      )
    )

    let executor = makeExecutor(database, for: propertyID, maxRuns: 0)

    // Property that never fails: replay should pass.
    let result = try await executor.execute { _ in
      return
    }

    guard case .passed = result else {
      Issue.record("Expected passed but got failure")
      return
    }

    // The original record should still be there, but no new one added.
    let traces = try await database.loadTraces(for: propertyID)
    #expect(traces.count == 1)
  }
}

/// Lightweight test error for property test failures.
private struct PropertyFailure: Error, CustomStringConvertible {
  let message: String
  var description: String { message }
}
