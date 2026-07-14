import PremiseCore
import PremiseDatabase
import Foundation
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif
import Testing

/// Round-trip tests for ``SQLiteBackedDatabase``.
///
/// Each test uses a unique temporary directory to isolate side effects.
/// Tests are disabled when the runtime SQLite library is below the WAL-safe
/// boundary.
@Suite(
  "SQLiteBackedDatabase round-trip persistence",
  .enabled(if: SQLiteRuntimeGate.isWALSafe(), "SQLite runtime below WAL-safe boundary")
)
struct SQLiteBackedDatabaseTests {

  // MARK: - Helpers

  /// Creates a temporary SQLite database path inside a unique directory.
  private func makeTempDBPath() throws -> (path: String, cleanup: @Sendable () -> Void) {
    let dir = NSTemporaryDirectory() + UUID().uuidString + "/"
    try FileManager.default.createDirectory(
      atPath: dir,
      withIntermediateDirectories: true
    )
    let path = dir + "test.sqlite"
    let cleanup: @Sendable () -> Void = {
      try? FileManager.default.removeItem(atPath: dir)
    }
    return (path, cleanup)
  }

  /// Builds a ``PropertyIdentity`` for testing.
  private func makePropertyID(
    fileID: String = "TestFile.swift",
    line: UInt = 42,
    strategyLabel: String = "Int"
  ) -> PropertyIdentity {
    PropertyIdentity(
      fileID: fileID,
      line: line,
      strategyLabel: strategyLabel
    )
  }

  /// Builds a ``FailureRecord`` with a given property identity and trace.
  private func makeRecord(
    propertyID: PropertyIdentity,
    entries: [ChoiceTrace.Entry] = [.integer(7)],
    timestamp: Date = Date(timeIntervalSince1970: 1_000_000)
  ) -> FailureRecord {
    FailureRecord(
      propertyID: propertyID,
      trace: ChoiceTrace(entries: entries),
      errorMessage: "test failure",
      runCount: 3,
      shrinkCount: 1,
      timestamp: timestamp,
      engineVersion: "0.2.0"
    )
  }

  // MARK: - Tests

  @Test("Save and load round-trip produces identical trace")
  func saveAndLoadRoundTrip() async throws {
    let (path, cleanup) = try makeTempDBPath()
    defer { cleanup() }

    let db = try SQLiteBackedDatabase(path: path)
    let id = makePropertyID()
    let record = makeRecord(propertyID: id)

    try await db.save(record)
    let traces = try await db.loadTraces(for: id)

    #expect(traces.count == 1)
    #expect(traces[0] == record.trace)
  }

  @Test("Loading traces for unknown property returns empty array")
  func loadTracesReturnsEmptyForUnknownProperty() async throws {
    let (path, cleanup) = try makeTempDBPath()
    defer { cleanup() }

    let db = try SQLiteBackedDatabase(path: path)
    let id = makePropertyID(fileID: "Unknown.swift", line: 999)

    let traces = try await db.loadTraces(for: id)
    #expect(traces.isEmpty)
  }

  @Test("Clear removes records for the given property")
  func clearRemovesRecords() async throws {
    let (path, cleanup) = try makeTempDBPath()
    defer { cleanup() }

    let db = try SQLiteBackedDatabase(path: path)
    let id = makePropertyID()
    let record = makeRecord(propertyID: id)

    try await db.save(record)
    try await db.clear(for: id)
    let traces = try await db.loadTraces(for: id)

    #expect(traces.isEmpty)
  }

  @Test("Multiple records for same property return in insertion order")
  func multipleRecordsSameProperty() async throws {
    let (path, cleanup) = try makeTempDBPath()
    defer { cleanup() }

    let db = try SQLiteBackedDatabase(path: path)
    let id = makePropertyID()

    let record1 = makeRecord(
      propertyID: id,
      entries: [.integer(1)],
      timestamp: Date(timeIntervalSince1970: 1_000_000)
    )
    let record2 = makeRecord(
      propertyID: id,
      entries: [.integer(2)],
      timestamp: Date(timeIntervalSince1970: 2_000_000)
    )

    try await db.save(record1)
    try await db.save(record2)

    let traces = try await db.loadTraces(for: id)
    #expect(traces.count == 2)
    #expect(traces[0] == ChoiceTrace(entries: [.integer(1)]))
    #expect(traces[1] == ChoiceTrace(entries: [.integer(2)]))
  }

  @Test("Saved row contains correct column values")
  func saveAndLoadPreservesAllFields() async throws {
    let (path, cleanup) = try makeTempDBPath()
    defer { cleanup() }

    let id = makePropertyID(fileID: "Fields.swift", line: 77, strategyLabel: "String")
    let timestamp = Date(timeIntervalSince1970: 1_234_567)
    let record = makeRecord(propertyID: id, timestamp: timestamp)

    let db = try SQLiteBackedDatabase(path: path)
    try await db.save(record)

    // Open a second raw connection to verify column values directly.
    var rawDB: OpaquePointer?
    let openResult = sqlite3_open_v2(path, &rawDB, SQLITE_OPEN_READONLY, nil)
    guard openResult == SQLITE_OK, let database = rawDB else {
      if let database = rawDB { sqlite3_close(database) }
      Issue.record("Failed to open database for verification")
      return
    }
    defer { sqlite3_close(database) }

    var stmt: OpaquePointer?
    // swiftlint:disable:next line_length
    let sql =
      "SELECT property_file_id, property_line, strategy_label, trace_format_version, record_format_version, created_at_unix_ms FROM failures LIMIT 1;"
    let prepResult = sqlite3_prepare_v2(database, sql, -1, &stmt, nil)
    guard prepResult == SQLITE_OK, let statement = stmt else {
      Issue.record("Failed to prepare verification query")
      return
    }
    defer { sqlite3_finalize(statement) }

    guard sqlite3_step(statement) == SQLITE_ROW else {
      Issue.record("No rows found in failures table")
      return
    }

    let fileIDValue = String(cString: sqlite3_column_text(statement, 0))
    let lineValue = sqlite3_column_int64(statement, 1)
    let strategyValue = String(cString: sqlite3_column_text(statement, 2))
    let traceFormatVersion = sqlite3_column_int(statement, 3)
    let recordFormatVersion = sqlite3_column_int(statement, 4)
    let createdAtMs = sqlite3_column_int64(statement, 5)

    #expect(fileIDValue == "Fields.swift")
    #expect(lineValue == 77)
    #expect(strategyValue == "String")
    #expect(traceFormatVersion == 1)
    #expect(recordFormatVersion == 1)
    #expect(createdAtMs == Int64(timestamp.timeIntervalSince1970 * 1000))
  }
}
