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

  /// Best-effort diagnostic output; a failing stderr while the tool is
  /// already reporting an error leaves nothing sensible to do.
  package static func logError(_ message: String) {
    try? FileHandle.standardError.write(contentsOf: Data("\(message)\n".utf8))
  }
}
