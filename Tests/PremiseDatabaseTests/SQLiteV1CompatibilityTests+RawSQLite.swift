import Foundation
import PremiseCore
import PremiseDatabase
import PremiseSQLite

extension SQLiteV1CompatibilityTests {
  // Manually inserts a row into the failures table using raw SQLite C API.
  // swiftlint:disable:next function_parameter_count
  func insertRawRow(
    database: OpaquePointer,
    propertyID: PropertyIdentity,
    traceFormatVersion: Int32,
    recordFormatVersion: Int32,
    traceJSON: Data,
    recordJSON: Data,
    createdAtMs: Int64
  ) throws {
    let statement = try prepareInsert(database)
    defer { sqlite3_finalize(statement) }

    bindIdentity(statement, propertyID: propertyID)
    sqlite3_bind_int(statement, 4, traceFormatVersion)
    sqlite3_bind_int(statement, 5, recordFormatVersion)
    bindPayload(statement, traceJSON: traceJSON, recordJSON: recordJSON)
    sqlite3_bind_int64(statement, 8, createdAtMs)

    let stepResult = sqlite3_step(statement)
    guard stepResult == SQLITE_DONE else {
      let msg = String(cString: sqlite3_errmsg(database))
      throw SQLiteError.resultCode(stepResult, context: msg)
    }
  }

  private func prepareInsert(
    _ database: OpaquePointer
  ) throws -> OpaquePointer {
    let sql = """
      INSERT INTO failures \
      (property_file_id, property_line, strategy_label, \
      trace_format_version, record_format_version, \
      trace_json, record_json, created_at_unix_ms) \
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      """
    var stmt: OpaquePointer?
    let prepResult = sqlite3_prepare_v2(database, sql, -1, &stmt, nil)
    guard prepResult == SQLITE_OK, let statement = stmt else {
      let msg = String(cString: sqlite3_errmsg(database))
      throw SQLiteError.resultCode(prepResult, context: msg)
    }
    return statement
  }

  private func bindIdentity(
    _ statement: OpaquePointer,
    propertyID: PropertyIdentity
  ) {
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    _ = propertyID.fileID.withCString { cstr in
      sqlite3_bind_text(statement, 1, cstr, -1, transient)
    }
    sqlite3_bind_int64(statement, 2, Int64(propertyID.line))
    _ = propertyID.strategyLabel.withCString { cstr in
      sqlite3_bind_text(statement, 3, cstr, -1, transient)
    }
  }

  private func bindPayload(
    _ statement: OpaquePointer,
    traceJSON: Data,
    recordJSON: Data
  ) {
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    traceJSON.withUnsafeBytes { buffer in
      guard let base = buffer.baseAddress else { return }
      sqlite3_bind_blob(statement, 6, base, Int32(buffer.count), transient)
    }
    recordJSON.withUnsafeBytes { buffer in
      guard let base = buffer.baseAddress else { return }
      sqlite3_bind_blob(statement, 7, base, Int32(buffer.count), transient)
    }
  }
}
