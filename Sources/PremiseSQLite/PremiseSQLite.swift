// Single home for the platform split between Darwin's built-in SQLite3
// module and the Linux CSQLite system-library shim. Files that call the
// sqlite3 C API import PremiseSQLite unconditionally.
#if canImport(SQLite3)
  @_exported import SQLite3
#else
  @_exported import CSQLite
#endif
