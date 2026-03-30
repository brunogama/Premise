import SQLite3

/// Manages the lifecycle of a single SQLite database connection with
/// WAL-mode pragmas and automatic schema creation.
///
/// `SQLiteConnection` is designed to be owned by an actor (such as the
/// future `SQLiteBackedDatabase`). The owning actor serialises access,
/// so this class uses `@unchecked Sendable` to satisfy the concurrency
/// model without redundant internal locking.
///
/// On initialisation the connection:
/// 1. Validates WAL runtime safety via ``SQLiteRuntimeGate``.
/// 2. Opens the database file with `SQLITE_OPEN_FULLMUTEX`.
/// 3. Configures `busy_timeout`, `journal_mode`, `synchronous`, and
///    `wal_autocheckpoint` pragmas.
/// 4. Creates the schema if it does not already exist.
///
/// On deallocation the database handle is closed via `sqlite3_close_v2`.
public final class SQLiteConnection: @unchecked Sendable {
    /// The raw SQLite database handle.
    public let handle: OpaquePointer

    /// Opens a SQLite database at `path`, validates WAL safety, enables WAL,
    /// sets busy_timeout, and creates schema if needed.
    ///
    /// - Parameter path: Filesystem path to the `.sqlite` file.
    /// - Throws: ``SQLiteError`` on open, WAL gate, or schema failure.
    public init(path: String) throws {
        try SQLiteRuntimeGate.assertWALSafeRuntime()

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let openResult = sqlite3_open_v2(path, &db, flags, nil)

        guard openResult == SQLITE_OK, let database = db else {
            // Clean up partial handle if open failed but returned non-nil.
            if let database = db {
                sqlite3_close_v2(database)
            }
            throw SQLiteError.resultCode(
                openResult,
                context: "sqlite3_open_v2 failed for path: \(path)"
            )
        }

        self.handle = database

        do {
            sqlite3_busy_timeout(database, 5000)
            try SQLiteSchema.exec(database, "PRAGMA journal_mode=WAL;")
            try SQLiteSchema.exec(database, "PRAGMA synchronous=NORMAL;")
            try SQLiteSchema.exec(database, "PRAGMA wal_autocheckpoint=1000;")
            try SQLiteSchema.createSchemaIfNeeded(database)
        } catch {
            sqlite3_close_v2(database)
            throw error
        }
    }

    deinit {
        sqlite3_close_v2(handle)
    }
}
