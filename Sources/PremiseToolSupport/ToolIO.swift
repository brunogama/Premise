import Foundation

/// Shared stdio for Premise command-line tools.
///
/// Writes through `FileHandle` rather than C stdio globals — Glibc exposes
/// `stderr` as a mutable global `var` that Swift 6 strict concurrency
/// rejects on Linux.
package enum ToolIO {
  /// Writes the tool's product output to standard output.
  ///
  /// Throws on write failure so callers exit nonzero instead of silently
  /// reporting success with missing output.
  package static func emit(_ message: String) throws {
    try FileHandle.standardOutput.write(contentsOf: Data("\(message)\n".utf8))
  }

  /// Writes diagnostic output to standard error.
  ///
  /// If writing to `stderr` fails, a best-effort fallback writes to `stdout`
  /// before propagating the failure to the caller.
  package static func logError(_ message: String) throws {
    do {
      try FileHandle.standardError.write(contentsOf: Data("\(message)\n".utf8))
    } catch {
      _ = try? FileHandle.standardOutput.write(contentsOf: Data("\(message)\n".utf8))
      throw error
    }
  }
}
