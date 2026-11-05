import Foundation

/// Appends structured run events to a JSON Lines file.
public enum RunJSONLWriter {
  private static let appendLock = NSLock()

  /// Appends one event as a single line, creating parent directories as needed.
  public static func append(_ event: RunJSONLEvent, to fileURL: URL) throws {
    let line = try event.encodedLine() + "\n"
    guard let data = line.data(using: .utf8) else {
      throw ChoiceTraceBlobError.malformed("JSONL event is not valid UTF-8")
    }

    appendLock.lock()
    defer { appendLock.unlock() }

    let directory = fileURL.deletingLastPathComponent()
    if !directory.path.isEmpty {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
    }

    try append(data, to: fileURL)
  }

  private static func append(_ data: Data, to fileURL: URL) throws {
    if FileManager.default.fileExists(atPath: fileURL.path) {
      let handle = try FileHandle(forWritingTo: fileURL)
      defer { try? handle.close() }
      try handle.seekToEnd()
      try handle.write(contentsOf: data)
    } else {
      try data.write(to: fileURL, options: [.atomic])
    }
  }
}
