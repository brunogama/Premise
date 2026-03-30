import PremiseCore

/// Formats a property failure into a human-readable diagnostic string
/// containing the counterexample, run/shrink counts, and replay instructions.
enum FailureFormatter {
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

    // Header with location.
    let location: String
    if let fn = propertyID.functionName {
      location = "\(propertyID.fileID) \(fn)#\(propertyID.line)"
    } else {
      location = "\(propertyID.fileID)#\(propertyID.line)"
    }
    lines.append("Property failed: \(location)")

    // Pretty-printed counterexample (use dump for complex types).
    let valueDescription = prettyPrint(value)
    lines.append("Counterexample: \(valueDescription)")

    // Error detail.
    lines.append("Error: \(record.errorMessage)")

    // Run/shrink summary.
    lines.append("Runs: \(record.runCount), Shrinks: \(record.shrinkCount)")

    // Seed-based replay instruction.
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

  // MARK: - Pretty-printing

  /// Renders a value for diagnostic output.
  ///
  /// For structs and classes with named fields the output is expanded
  /// into a multi-line breakdown so that complex counterexamples are
  /// readable.  Primitives and collections use `String(describing:)`
  /// to preserve backward compatibility and parity with
  /// `XCTestFailureFormatter`.
  static func prettyPrint(_ value: some Any) -> String {
    let mirror = Mirror(reflecting: value)

    // For structs/classes with named fields, show field breakdown.
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
