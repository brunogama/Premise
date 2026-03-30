import PremiseCore

/// Formats a property failure into a human-readable diagnostic string
/// for XCTest output containing the counterexample, run/shrink counts,
/// and replay instructions.
enum XCTestFailureFormatter {
  /// Builds a diagnostic message from a property failure.
  ///
  /// - Parameters:
  ///   - value: The minimized counterexample that triggered the failure.
  ///   - record: The failure record containing trace, counts, and metadata.
  ///   - propertyID: The property identity for replay instructions.
  /// - Returns: A multi-line diagnostic string.
  static func format<Value>(
    value: Value,
    record: FailureRecord,
    propertyID: PropertyIdentity
  ) -> String {
    var lines: [String] = []
    let location: String
    if let fn = propertyID.functionName {
      location = "\(propertyID.fileID) \(fn)#\(propertyID.line)"
    } else {
      location = "\(propertyID.fileID)#\(propertyID.line)"
    }
    lines.append("Property failed: \(location)")
    lines.append("Counterexample: \(value)")
    lines.append("Error: \(record.errorMessage)")
    lines.append("Runs: \(record.runCount), Shrinks: \(record.shrinkCount)")
    if let seed = record.seed {
      lines.append("Seed to reproduce: \(seed)")
      lines.append("Replay: config: PropertyConfig(seed: \(seed))")
    } else {
      lines.append(
        "Replay: use trace from "
          + ".premise/examples to reproduce this failure."
      )
    }
    return lines.joined(separator: "\n")
  }
}
