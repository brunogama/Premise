import SQLite3

/// DDL definitions and schema management for the Premise failures database.
///
/// The schema creates a `failures` table with versioned format columns,
/// sets the SQLite `application_id` to the CONJ magic number, and tracks
/// the schema version via `user_version`.
public enum SQLiteSchema {
  /// CONJ in ASCII hex: 0x434F4E4A (1129270858).
  public static let applicationID: Int32 = 0x434F_4E4A

  /// Current schema version.
  public static let schemaVersion: Int32 = 1

  /// Creates the failures table and sets `application_id` + `user_version`
  /// if they are not already set.
  ///
  /// Calling this method on a database that already has the schema is safe
  /// (idempotent). The `user_version` pragma is checked first; if it already
  /// matches ``schemaVersion``, the method returns immediately.
  ///
  /// - Parameter database: An open SQLite database handle.
  /// - Throws: ``SQLiteError/resultCode(_:context:)`` on DDL failure.
  public static func createSchemaIfNeeded(
    _ database: OpaquePointer
  ) throws {
    let currentVersion = try userVersion(database)
    guard currentVersion == 0 else { return }

    try exec(database, "PRAGMA application_id = \(applicationID);")
    try exec(database, "PRAGMA user_version = \(schemaVersion);")

    try createFailuresTable(database)
    try exec(
      database,
      """
      CREATE INDEX IF NOT EXISTS idx_failures_property
        ON failures (property_file_id, property_line, strategy_label);
      """
    )
  }

  private static func createFailuresTable(_ database: OpaquePointer) throws {
    try exec(
      database,
      """
      CREATE TABLE IF NOT EXISTS failures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        property_file_id TEXT NOT NULL,
        property_line INTEGER NOT NULL,
        strategy_label TEXT NOT NULL,
        trace_format_version INTEGER NOT NULL,
        record_format_version INTEGER NOT NULL,
        trace_json BLOB NOT NULL,
        record_json BLOB NOT NULL,
        created_at_unix_ms INTEGER NOT NULL
      );
      """
    )

  }

  // MARK: - Helpers

  /// Executes a SQL statement on the given database handle.
  ///
  /// - Parameters:
  ///   - database: An open SQLite database handle.
  ///   - sql: The SQL string to execute.
  /// - Throws: ``SQLiteError/resultCode(_:context:)`` when the result
  ///   is not `SQLITE_OK`.
  static func exec(_ database: OpaquePointer, _ sql: String) throws {
    let result = sqlite3_exec(database, sql, nil, nil, nil)
    guard result == SQLITE_OK else {
      let message = String(cString: sqlite3_errmsg(database))
      throw SQLiteError.resultCode(result, context: message)
    }
  }

  /// Reads the current `PRAGMA user_version` value.
  ///
  /// - Parameter database: An open SQLite database handle.
  /// - Returns: The integer user version, or 0 if unset.
  /// - Throws: ``SQLiteError/resultCode(_:context:)`` on failure.
  private static func userVersion(_ database: OpaquePointer) throws -> Int32 {
    var stmt: OpaquePointer?
    let sql = "PRAGMA user_version;"
    let prepareResult = sqlite3_prepare_v2(database, sql, -1, &stmt, nil)
    guard prepareResult == SQLITE_OK, let statement = stmt else {
      let message = String(cString: sqlite3_errmsg(database))
      throw SQLiteError.resultCode(prepareResult, context: message)
    }
    defer { sqlite3_finalize(statement) }

    guard sqlite3_step(statement) == SQLITE_ROW else {
      return 0
    }
    return sqlite3_column_int(statement, 0)
  }
}
