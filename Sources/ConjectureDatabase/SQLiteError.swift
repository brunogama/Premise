/// Typed error domain for SQLite operations in the persistence layer.
///
/// Every error case carries enough context for callers to produce
/// actionable diagnostics without exposing raw C API details.
public enum SQLiteError: Error, Equatable, Sendable {
    /// A SQLite C API call returned a non-OK result code.
    case resultCode(Int32, context: String)

    /// The runtime SQLite library version is below the WAL-safe boundary.
    case unsupportedWALRuntime(versionNumber: Int32)
}
