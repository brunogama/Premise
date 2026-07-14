#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif

/// Fail-fast runtime check ensuring the linked SQLite library supports
/// WAL mode without the known corruption bugs fixed in 3.51.3.
///
/// Call ``assertWALSafeRuntime()`` before enabling `PRAGMA journal_mode=WAL`.
/// The gate also recognises specific backport versions that include the fix.
public enum SQLiteRuntimeGate {
  /// Minimum safe SQLite version for WAL (3.51.3 = 3051003).
  public static let minimumSafeVersion: Int32 = 3_051_003

  /// Backport versions known to include the WAL-reset fix.
  public static let safeBackports: Set<Int32> = [3_050_007, 3_044_006]

  /// Returns `true` when the linked SQLite runtime is safe for WAL mode.
  public static func isWALSafe() -> Bool {
    let version = sqlite3_libversion_number()
    return version >= minimumSafeVersion || safeBackports.contains(version)
  }

  /// Throws ``SQLiteError/unsupportedWALRuntime(versionNumber:)`` if the
  /// runtime is not safe for WAL mode.
  ///
  /// - Throws: ``SQLiteError`` when the linked library is below the safe
  ///   version and not in the known-good backports set.
  public static func assertWALSafeRuntime() throws {
    guard isWALSafe() else {
      throw SQLiteError.unsupportedWALRuntime(
        versionNumber: sqlite3_libversion_number()
      )
    }
  }
}
