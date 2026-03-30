---
phase: 05-sqlite-wal-persistence
plan: 01
subsystem: persistence
tags: [sqlite, wal, schema, runtime-gate]
dependency_graph:
  requires: []
  provides: [SQLiteError, SQLiteRuntimeGate, SQLiteConnection, SQLiteSchema]
  affects: [ConjectureDatabase]
tech_stack:
  added: [SQLite3]
  patterns: [runtime-gating, WAL-mode, versioned-schema]
key_files:
  created:
    - Sources/ConjectureDatabase/SQLiteError.swift
    - Sources/ConjectureDatabase/SQLiteRuntimeGate.swift
    - Sources/ConjectureDatabase/SQLiteConnection.swift
    - Sources/ConjectureDatabase/SQLiteSchema.swift
    - Tests/ConjectureDatabaseTests/SQLiteRuntimeGateTests.swift
    - Tests/ConjectureDatabaseTests/SQLiteSchemaTests.swift
  modified: []
decisions:
  - Used enum namespaces (SQLiteRuntimeGate, SQLiteSchema) for stateless utility types
  - SQLiteConnection is final class with @unchecked Sendable (actor-owned serialization)
  - Schema exec helper is internal (static, not private) so SQLiteConnection can reuse it
metrics:
  duration: 3min
  completed: "2026-03-30T08:23:00Z"
  tasks: 2
  files: 6
---

# Phase 05 Plan 01: SQLite Foundation Layer Summary

SQLite WAL runtime gate, typed errors, connection lifecycle with pragma configuration, and versioned failures table DDL.

## What Was Built

### SQLiteError (typed error domain)
- `resultCode(Int32, context: String)` for C API failures
- `unsupportedWALRuntime(versionNumber: Int32)` for runtime gate failures
- Equatable, Sendable, Error conformance

### SQLiteRuntimeGate (WAL safety check)
- `minimumSafeVersion` = 3,051,003 (SQLite 3.51.3)
- `safeBackports` = {3,050,007, 3,044,006}
- `isWALSafe()` checks linked runtime version
- `assertWALSafeRuntime()` throws on unsafe runtimes

### SQLiteSchema (DDL management)
- `applicationID` = 0x434F4E4A (CONJ magic number)
- `schemaVersion` = 1
- `createSchemaIfNeeded(_:)` creates failures table with versioned columns
- Index on (property_file_id, property_line, strategy_label)
- Idempotent: checks user_version before applying DDL

### SQLiteConnection (lifecycle management)
- Opens database with SQLITE_OPEN_FULLMUTEX
- Validates WAL safety before enabling journal_mode=WAL
- Configures busy_timeout=5000, synchronous=NORMAL, wal_autocheckpoint=1000
- Creates schema on first open
- Closes handle in deinit with sqlite3_close_v2

## Test Coverage

- **SQLiteRuntimeGateTests** (4 tests): version constants, backport set, isWALSafe smoke, assertWALSafeRuntime behavior
- **SQLiteSchemaTests** (6 tests): applicationID value, schemaVersion value, pragma setting, table creation, idempotency, WAL connection gate

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed sqlite3_bind_text destructor in test helper**
- **Found during:** Task 2 verification
- **Issue:** `sqlite3_bind_text` with `nil` destructor caused text parameter to not bind correctly in test helper
- **Fix:** Replaced parameterized query with inline string in test-only helper
- **Files modified:** Tests/ConjectureDatabaseTests/SQLiteSchemaTests.swift

## Known Stubs

None.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 6e012b7 | SQLiteError and SQLiteRuntimeGate with 4 tests |
| 2 | 9fbb286 | SQLiteConnection and SQLiteSchema with 6 tests |

## Self-Check: PASSED

- All 6 created files verified present on disk
- Commits 6e012b7 and 9fbb286 verified in git log
- 10/10 tests passing, zero warnings with -warnings-as-errors
