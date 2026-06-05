import PremiseCore
import Foundation

/// Writes JSON failure trace artifacts for CI systems and local replay.
public enum FailureTraceExporter {
  public static func export(
    _ artifact: FailureTraceArtifact,
    to directory: URL
  ) throws -> URL {
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )

    let fileURL = directory.appendingPathComponent(
      fileName(for: artifact.record)
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(artifact)
    try data.write(to: fileURL, options: [.atomic])
    return fileURL
  }

  private static func fileName(for record: FailureRecord) -> String {
    let key = [
      record.propertyID.fileID,
      record.propertyID.functionName ?? "L\(record.propertyID.line)",
      record.propertyID.strategyLabel,
      String(Int(record.timestamp.timeIntervalSince1970 * 1000)),
    ].joined(separator: "#")
    let hexName = Data(key.utf8).map { String(format: "%02x", $0) }.joined()
    return "\(hexName).premise-trace.json"
  }
}
