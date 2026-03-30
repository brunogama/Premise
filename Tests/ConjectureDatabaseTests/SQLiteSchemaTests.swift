import Foundation
import SQLite3
import Testing

@testable import ConjectureDatabase

@Suite("SQLiteSchema")
struct SQLiteSchemaTests {

    // MARK: - Helpers

    /// Opens an in-memory SQLite database, bypassing the WAL runtime gate.
    /// In-memory databases cannot use WAL but are perfect for testing DDL.
    private func openInMemoryDB() throws -> OpaquePointer {
        var db: OpaquePointer?
        let result = sqlite3_open(":memory:", &db)
        guard result == SQLITE_OK, let database = db else {
            if let database = db { sqlite3_close(database) }
            throw SQLiteError.resultCode(result, context: "in-memory open failed")
        }
        return database
    }

    /// Reads a single Int32 value from a PRAGMA query.
    private func pragmaInt32(_ db: OpaquePointer, _ pragma: String) throws -> Int32 {
        var stmt: OpaquePointer?
        let sql = "PRAGMA \(pragma);"
        let prepareResult = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard prepareResult == SQLITE_OK, let statement = stmt else {
            throw SQLiteError.resultCode(prepareResult, context: "prepare \(pragma)")
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return sqlite3_column_int(statement, 0)
    }

    /// Queries whether a table exists in sqlite_master.
    private func tableExists(_ db: OpaquePointer, name: String) throws -> Bool {
        var stmt: OpaquePointer?
        let sql = "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='\(name)';"
        let result = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard result == SQLITE_OK, let statement = stmt else {
            throw SQLiteError.resultCode(result, context: "table check")
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return false }
        return sqlite3_column_int(statement, 0) > 0
    }

    // MARK: - Tests

    @Test("applicationID equals CONJ magic number")
    func applicationIDValue() {
        #expect(SQLiteSchema.applicationID == 0x434F_4E4A)
        #expect(SQLiteSchema.applicationID == 1_129_270_858)
    }

    @Test("schemaVersion equals 1")
    func schemaVersionValue() {
        #expect(SQLiteSchema.schemaVersion == 1)
    }

    @Test("createSchemaIfNeeded sets application_id and user_version")
    func schemaSetsPragmas() throws {
        let db = try openInMemoryDB()
        defer { sqlite3_close(db) }

        try SQLiteSchema.createSchemaIfNeeded(db)

        let appID = try pragmaInt32(db, "application_id")
        #expect(appID == SQLiteSchema.applicationID)

        let version = try pragmaInt32(db, "user_version")
        #expect(version == SQLiteSchema.schemaVersion)
    }

    @Test("createSchemaIfNeeded creates the failures table")
    func schemaCreatesTable() throws {
        let db = try openInMemoryDB()
        defer { sqlite3_close(db) }

        try SQLiteSchema.createSchemaIfNeeded(db)

        let exists = try tableExists(db, name: "failures")
        #expect(exists)
    }

    @Test("createSchemaIfNeeded is idempotent")
    func schemaIdempotent() throws {
        let db = try openInMemoryDB()
        defer { sqlite3_close(db) }

        try SQLiteSchema.createSchemaIfNeeded(db)
        try SQLiteSchema.createSchemaIfNeeded(db)

        let appID = try pragmaInt32(db, "application_id")
        #expect(appID == SQLiteSchema.applicationID)

        let exists = try tableExists(db, name: "failures")
        #expect(exists)
    }

    @Test("SQLiteConnection either opens with WAL or throws on unsafe runtime")
    func connectionWALGate() throws {
        if SQLiteRuntimeGate.isWALSafe() {
            let tempDir = NSTemporaryDirectory()
            let path = tempDir + "conjecture_test_\(ProcessInfo.processInfo.processIdentifier).sqlite"
            defer {
                try? FileManager.default.removeItem(atPath: path)
                try? FileManager.default.removeItem(atPath: path + "-wal")
                try? FileManager.default.removeItem(atPath: path + "-shm")
            }

            let connection = try SQLiteConnection(path: path)

            // Verify WAL is active.
            var stmt: OpaquePointer?
            let result = sqlite3_prepare_v2(connection.handle, "PRAGMA journal_mode;", -1, &stmt, nil)
            guard result == SQLITE_OK, let statement = stmt else {
                throw SQLiteError.resultCode(result, context: "pragma check")
            }
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW else {
                Issue.record("Expected SQLITE_ROW from PRAGMA journal_mode")
                return
            }
            let mode = String(cString: sqlite3_column_text(statement, 0))
            #expect(mode == "wal")
        } else {
            let version = sqlite3_libversion_number()
            #expect(throws: SQLiteError.unsupportedWALRuntime(versionNumber: version)) {
                _ = try SQLiteConnection(path: ":memory:")
            }
        }
    }
}
