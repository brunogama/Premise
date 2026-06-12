import Foundation

/// Writes `contents` to a temporary file, passes its URL to `body`, then removes it.
///
/// The URL is valid only while `body` is running. Cleanup runs after `body`
/// returns, throws, or is cancelled, so callers must not use the URL from
/// detached work after `body` returns.
public func withTemporaryFile<T>(
  contents: Data,
  extension pathExtension: String? = nil,
  _ body: @Sendable (URL) async throws -> T
) async throws -> T {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(
    at: directory,
    withIntermediateDirectories: true
  )
  defer { try? FileManager.default.removeItem(at: directory) }

  let fileURL = temporaryFileURL(in: directory, pathExtension: pathExtension)
  try contents.write(to: fileURL, options: [.atomic])
  return try await body(fileURL)
}

/// Writes `contents` to a temporary file, passes its URL to `body`, then removes it.
///
/// The URL is valid only while `body` is running. Cleanup runs after `body`
/// returns, throws, or is cancelled, so callers must not use the URL from
/// detached work after `body` returns.
public func withTemporaryFile<T>(
  contents: Data,
  extension pathExtension: String? = nil,
  _ body: (URL) throws -> T
) throws -> T {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(
    at: directory,
    withIntermediateDirectories: true
  )
  defer { try? FileManager.default.removeItem(at: directory) }

  let fileURL = temporaryFileURL(in: directory, pathExtension: pathExtension)
  try contents.write(to: fileURL, options: [.atomic])
  return try body(fileURL)
}

private func temporaryFileURL(in directory: URL, pathExtension: String?) -> URL {
  let base = directory.appendingPathComponent("premise-fixture", isDirectory: false)
  guard let pathExtension, !pathExtension.isEmpty else {
    return base
  }

  let normalized = pathExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
  guard !normalized.isEmpty else {
    return base
  }
  return base.appendingPathExtension(normalized)
}
