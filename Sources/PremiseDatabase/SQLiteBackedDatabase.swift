import PremiseCore
import Foundation
import PremiseSQLite

/// SQLite WAL-backed failure store implementing the ``ExampleDatabase`` contract.
///
/// The actor owns a single ``SQLiteConnection`` and serializes all reads and
/// writes through the actor mailbox. Records are stored with explicit
/// `trace_format_version` and `record_format_version` columns so that
/// compatibility can be validated before decode.
public actor SQLiteBackedDatabase: ExampleDatabase {
  private let connection: SQLiteConnection

  /// Opens (or creates) a SQLite database at `path`.
  ///
  /// - Parameter path: Filesystem path to the `.sqlite` file.
  ///   Defaults to `.premise/examples.sqlite`.
  /// - Throws: ``SQLiteError`` if the runtime is WAL-unsafe, if the file
  ///   cannot be opened, or if schema creation fails.
  public init(path: String = ".premise/examples.sqlite") throws {
    self.connection = try SQLiteConnection(path: path)
  }

  // MARK: - ExampleDatabase

  /// Stores a failure record.
  public func save(_ record: FailureRecord) async throws {
    let envelope = PersistenceCodec.encode(record)

    let traceData = try JSONEncoder().encode(record.trace)
    let recordData = try JSONEncoder().encode(envelope)
    let createdAtMs = Int64(record.timestamp.timeIntervalSince1970 * 1000)

    let sql = """
      INSERT INTO failures \
      (property_file_id, property_line, strategy_label, \
      trace_format_version, record_format_version, \
      trace_json, record_json, created_at_unix_ms) \
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      """

    let stmt = try prepareStatement(sql)
    defer { PremiseSQLite.sqlite3_finalize(stmt) }

    bindPropertyIdentity(stmt, record.propertyID, startingAt: 1)
    PremiseSQLite.sqlite3_bind_int(stmt, 4, Int32(envelope.traceFormatVersion))
    PremiseSQLite.sqlite3_bind_int(stmt, 5, Int32(envelope.recordFormatVersion))

    bindBlob(traceData, to: stmt, at: 6)
    bindBlob(recordData, to: stmt, at: 7)

    PremiseSQLite.sqlite3_bind_int64(stmt, 8, createdAtMs)

    try stepToCompletion(stmt)
  }

  /// Loads stored traces for a property.
  public func loadTraces(
    for id: PropertyIdentity
  ) async throws -> [ChoiceTrace] {
    let sql = """
      SELECT trace_format_version, record_format_version, trace_json \
      FROM failures \
      WHERE property_file_id = ? AND property_line = ? AND strategy_label = ? \
      ORDER BY created_at_unix_ms ASC
      """

    let stmt = try prepareStatement(sql)
    defer { PremiseSQLite.sqlite3_finalize(stmt) }

    bindPropertyIdentity(stmt, id, startingAt: 1)

    var traces: [ChoiceTrace] = []

    while PremiseSQLite.sqlite3_step(stmt) == SQLITE_ROW {
      try validateVersions(stmt)

      guard let blobPointer = PremiseSQLite.sqlite3_column_blob(stmt, 2) else {
        continue
      }
      let blobLength = Int(PremiseSQLite.sqlite3_column_bytes(stmt, 2))
      let data = Data(bytes: blobPointer, count: blobLength)
      traces.append(try JSONDecoder().decode(ChoiceTrace.self, from: data))
    }

    return traces
  }

  /// Removes stored failures for a property.
  public func clear(for id: PropertyIdentity) async throws {
    let sql = """
      DELETE FROM failures \
      WHERE property_file_id = ? AND property_line = ? AND strategy_label = ?
      """

    let stmt = try prepareStatement(sql)
    defer { PremiseSQLite.sqlite3_finalize(stmt) }

    bindPropertyIdentity(stmt, id, startingAt: 1)

    try stepToCompletion(stmt)
  }

}

extension SQLiteBackedDatabase {
  private func stepToCompletion(_ stmt: OpaquePointer) throws {
    let result = PremiseSQLite.sqlite3_step(stmt)
    guard result == SQLITE_DONE else {
      let message =
        String(cString: PremiseSQLite.sqlite3_errmsg(connection.handle))
      throw SQLiteError.resultCode(result, context: message)
    }
  }

  private func bindBlob(_ data: Data, to stmt: OpaquePointer, at index: Int32) {
    data.withUnsafeBytes { buffer in
      guard let baseAddress = buffer.baseAddress else { return }
      PremiseSQLite.sqlite3_bind_blob(
        stmt,
        index,
        baseAddress,
        Int32(buffer.count),
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
      )
    }
  }

  private func validateVersions(_ stmt: OpaquePointer) throws {
    let traceVersion = Int(PremiseSQLite.sqlite3_column_int(stmt, 0))
    let recordVersion = Int(PremiseSQLite.sqlite3_column_int(stmt, 1))
    let traceVersions = PersistenceVersionPolicy.supportedTraceVersions
    guard traceVersions.contains(traceVersion) else {
      throw PersistenceCompatibilityError.unsupportedTraceVersion(
        found: traceVersion,
        supported: PersistenceVersionPolicy.supportedTraceVersions
      )
    }
    let recordVersions = PersistenceVersionPolicy.supportedRecordVersions
    guard recordVersions.contains(recordVersion) else {
      throw PersistenceCompatibilityError.unsupportedRecordVersion(
        found: recordVersion,
        supported: PersistenceVersionPolicy.supportedRecordVersions
      )
    }
  }

  /// Wraps `sqlite3_prepare_v2`, throwing ``SQLiteError`` on failure.
  ///
  /// - Parameter sql: The SQL statement to prepare.
  /// - Returns: A prepared statement pointer.
  /// - Throws: ``SQLiteError/resultCode(_:context:)`` on preparation failure.
  private func prepareStatement(_ sql: String) throws -> OpaquePointer {
    var stmt: OpaquePointer?
    let result =
      PremiseSQLite.sqlite3_prepare_v2(connection.handle, sql, -1, &stmt, nil)
    guard result == SQLITE_OK, let statement = stmt else {
      let message =
        String(cString: PremiseSQLite.sqlite3_errmsg(connection.handle))
      throw SQLiteError.resultCode(result, context: message)
    }
    return statement
  }

  /// Binds ``PropertyIdentity`` fields to consecutive parameter slots.
  ///
  /// - Parameters:
  ///   - stmt: The prepared statement.
  ///   - id: The property identity to bind.
  ///   - index: The 1-based parameter index for the first field.
  private func bindPropertyIdentity(
    _ stmt: OpaquePointer,
    _ id: PropertyIdentity,
    startingAt index: Int32
  ) {
    _ = id.fileID.withCString { cstr in
      PremiseSQLite.sqlite3_bind_text(
        stmt,
        index,
        cstr,
        -1,
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
      )
    }
    PremiseSQLite.sqlite3_bind_int64(stmt, index + 1, Int64(id.line))
    _ = id.strategyLabel.withCString { cstr in
      PremiseSQLite.sqlite3_bind_text(
        stmt,
        index + 2,
        cstr,
        -1,
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
      )
    }
  }
}
