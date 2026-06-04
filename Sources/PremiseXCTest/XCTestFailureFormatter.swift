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
    lines.append("Failure kind: \(record.discovery.rawValue)")
    lines.append("Minimal counterexample: \(prettyPrint(value))")
    lines.append("Error: \(record.errorMessage)")
    lines.append("Runs: \(record.runCount), Shrinks: \(record.shrinkCount)")
    lines.append("Trace entries: \(record.trace.entries.count)")
    if let seed = record.seed {
      lines.append("Seed to reproduce: \(seed)")
      lines.append("Replay: config: PropertyConfig(seed: \(seed))")
    } else {
      lines.append(
        "Replay: use the persisted trace from .premise/examples "
          + "or an exported JSON trace artifact."
      )
    }
    return lines.joined(separator: "\n")
  }

  static func prettyPrint(_ value: some Any) -> String {
    let mirror = Mirror(reflecting: value)

    if mirror.displayStyle == .struct || mirror.displayStyle == .class,
      !mirror.children.isEmpty,
      mirror.children.first?.label != nil
    {
      let fields = mirror.children.map { child in
        let label = child.label ?? "_"
        return "  \(label): \(child.value)"
      }
      let typeName = String(describing: type(of: value))
      return "\(typeName)(\n\(fields.joined(separator: "\n"))\n)"
    }

    return String(describing: value)
  }
}
