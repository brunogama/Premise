import PremiseCore
import PremiseDatabase
import Foundation
import SQLite3
import Testing

/// Backward compatibility tests verifying that v1 ``PersistedFailureRecordV1``
/// envelopes can be imported through SQLite and that unsupported future format
/// versions are rejected.
@Suite(
  "SQLite v1 compatibility",
  .enabled(
    if: SQLiteRuntimeGate.isWALSafe(),
    "SQLite runtime below WAL-safe boundary"
  )
)
struct SQLiteV1CompatibilityTests {

  // MARK: - Helpers

  /// Creates a temporary SQLite database path inside a unique directory.
  private func makeTempDBPath() throws -> (
    path: String, cleanup: @Sendable () -> Void
  ) {
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

  /// Builds a sample ``FailureRecord`` for compatibility testing.
  private func sampleRecord() -> FailureRecord {
    let trace = ChoiceTrace(
      entries: [.integer(42), .boolean(true)],
      spans: [ChoiceTrace.Span(label: "root", start: 0, end: 2)]
    )
    return FailureRecord(
      propertyID: PropertyIdentity(
        fileID: "Tests/Compat.swift",
        line: 10,
        strategyLabel: "integers"
      ),
      trace: trace,
      errorMessage: "compat test failure",
      runCount: 5,
      shrinkCount: 3,
      timestamp: Date(timeIntervalSince1970: 1_000_000),
      engineVersion: "0.2.0"
    )
  }

}

extension SQLiteV1CompatibilityTests {
  // MARK: - Tests

  @Test("v1 envelope imported through SQLite produces matching trace")
  func v1EnvelopeImportThroughSQLite() async throws {
    let (path, cleanup) = try makeTempDBPath()
    defer { cleanup() }

    let record = sampleRecord()
    let envelope = PersistenceCodec.encode(record)

    // Create the database (which creates schema) then insert manually.
    let database = try SQLiteBackedDatabase(path: path)

    // Open a raw connection for manual insertion.
    var rawDB: OpaquePointer?
    let openResult = sqlite3_open_v2(path, &rawDB, SQLITE_OPEN_READWRITE, nil)
    guard openResult == SQLITE_OK, let rawDatabase = rawDB else {
      if let rawDatabase = rawDB { sqlite3_close(rawDatabase) }
      Issue.record("Failed to open raw database")
      return
    }
    defer { sqlite3_close(rawDatabase) }

    try await verifyV1Import(
      database,
      rawDatabase: rawDatabase,
      input: (record, envelope)
    )
  }

  private func verifyV1Import(
    _ database: SQLiteBackedDatabase,
    rawDatabase: OpaquePointer,
    input: (FailureRecord, PersistedFailureRecordV1)
  ) async throws {
    let (record, envelope) = input
    let traceJSON = try JSONEncoder().encode(envelope.trace)
    let recordJSON = try JSONEncoder().encode(envelope)

    try insertRawRow(
      database: rawDatabase,
      propertyID: record.propertyID,
      traceFormatVersion: Int32(envelope.traceFormatVersion),
      recordFormatVersion: Int32(envelope.recordFormatVersion),
      traceJSON: traceJSON,
      recordJSON: recordJSON,
      createdAtMs: Int64(record.timestamp.timeIntervalSince1970 * 1000)
    )

    let traces = try await database.loadTraces(for: record.propertyID)
    #expect(traces.count == 1)
    #expect(traces[0] == record.trace)
  }

  @Test("Unsupported future trace version throws PersistenceCompatibilityError")
  func unsupportedFutureTraceVersionThrows() async throws {

    let (path, cleanup) = try makeTempDBPath()
    defer { cleanup() }

    let record = sampleRecord()
    let database = try SQLiteBackedDatabase(path: path)

    var rawDB: OpaquePointer?
    let openResult = sqlite3_open_v2(path, &rawDB, SQLITE_OPEN_READWRITE, nil)
    guard openResult == SQLITE_OK, let rawDatabase = rawDB else {
      if let rawDatabase = rawDB { sqlite3_close(rawDatabase) }
      Issue.record("Failed to open raw database")
      return
    }
    defer { sqlite3_close(rawDatabase) }

    try await verifyUnsupportedTrace(
      database,
      rawDatabase: rawDatabase,
      record: record
    )
  }

  private func verifyUnsupportedTrace(
    _ database: SQLiteBackedDatabase,
    rawDatabase: OpaquePointer,
    record: FailureRecord
  ) async throws {
    let traceJSON = try JSONEncoder().encode(record.trace)
    let envelope = PersistenceCodec.encode(record)
    let recordJSON = try JSONEncoder().encode(envelope)

    try insertRawRow(
      database: rawDatabase,
      propertyID: record.propertyID,
      traceFormatVersion: 99,
      recordFormatVersion: 1,
      traceJSON: traceJSON,
      recordJSON: recordJSON,
      createdAtMs: Int64(record.timestamp.timeIntervalSince1970 * 1000)
    )

    await #expect(
      throws: PersistenceCompatibilityError.unsupportedTraceVersion(
        found: 99,
        supported: 1...1
      )
    ) {
      _ = try await database.loadTraces(for: record.propertyID)
    }
  }

  @Test(
    "Unsupported future record version throws PersistenceCompatibilityError"
  )
  func unsupportedFutureRecordVersionThrows() async throws {

    let (path, cleanup) = try makeTempDBPath()
    defer { cleanup() }

    let record = sampleRecord()
    let database = try SQLiteBackedDatabase(path: path)

    var rawDB: OpaquePointer?
    let openResult = sqlite3_open_v2(path, &rawDB, SQLITE_OPEN_READWRITE, nil)
    guard openResult == SQLITE_OK, let rawDatabase = rawDB else {
      if let rawDatabase = rawDB { sqlite3_close(rawDatabase) }
      Issue.record("Failed to open raw database")
      return
    }
    defer { sqlite3_close(rawDatabase) }

    try await verifyUnsupportedRecord(
      database,
      rawDatabase: rawDatabase,
      record: record
    )
  }

  private func verifyUnsupportedRecord(
    _ database: SQLiteBackedDatabase,
    rawDatabase: OpaquePointer,
    record: FailureRecord
  ) async throws {
    let traceJSON = try JSONEncoder().encode(record.trace)
    let envelope = PersistenceCodec.encode(record)
    let recordJSON = try JSONEncoder().encode(envelope)

    try insertRawRow(
      database: rawDatabase,
      propertyID: record.propertyID,
      traceFormatVersion: 1,
      recordFormatVersion: 99,
      traceJSON: traceJSON,
      recordJSON: recordJSON,
      createdAtMs: Int64(record.timestamp.timeIntervalSince1970 * 1000)
    )

    await #expect(
      throws: PersistenceCompatibilityError.unsupportedRecordVersion(
        found: 99,
        supported: 1...1
      )
    ) {
      _ = try await database.loadTraces(for: record.propertyID)
    }
  }

  @Test("FileBackedDatabase and SQLiteBackedDatabase produce same traces")
  func fileBackedAndSQLiteProduceSameTraces() async throws {

    let (sqlitePath, sqliteCleanup) = try makeTempDBPath()
    defer { sqliteCleanup() }

    let fileDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: fileDir,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: fileDir) }

    let record = sampleRecord()

    let fileDB = FileBackedDatabase(rootDirectory: fileDir)
    try await fileDB.save(record)
    let fileTraces = try await fileDB.loadTraces(for: record.propertyID)

    let sqliteDB = try SQLiteBackedDatabase(path: sqlitePath)
    try await sqliteDB.save(record)
    let sqliteTraces = try await sqliteDB.loadTraces(for: record.propertyID)

    #expect(fileTraces == sqliteTraces)
    #expect(fileTraces.count == 1)
    #expect(sqliteTraces[0] == record.trace)
  }
}
