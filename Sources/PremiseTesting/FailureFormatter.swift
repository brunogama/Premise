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
  ///   - report: Optional detailed run report for aggregated diagnostics.
  /// - Returns: A multi-line diagnostic string.
  static func format<Value>(
    value: Value,
    record: FailureRecord,
    propertyID: PropertyIdentity,
    report: RunReport? = nil,
    includeReproductionBlob: Bool = false
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
    lines.append("Failure kind: \(record.discovery.rawValue)")

    // Pretty-printed counterexample (use dump for complex types).
    let valueDescription = prettyPrint(value)
    lines.append("Minimal counterexample: \(valueDescription)")

    // Error detail.
    lines.append("Error: \(record.errorMessage)")

    // Run/shrink summary.
    lines.append("Runs: \(record.runCount), Shrinks: \(record.shrinkCount)")
    lines.append("Trace entries: \(record.trace.entries.count)")
    appendStatistics(
      from: statistics(record: record, report: report),
      report: report,
      to: &lines
    )
    appendMultipleFailures(from: report, to: &lines)

    // Seed-based replay instruction.
    if let seed = record.seed {
      lines.append("Seed to reproduce: \(seed)")
      lines.append("Replay: config: PropertyConfig(seed: \(seed))")
    } else {
      lines.append(
        "Replay: use the persisted trace from .premise/examples "
          + "or an exported JSON trace artifact."
      )
    }

    if includeReproductionBlob, let blob = try? record.trace.reproductionBlob() {
      lines.append("Reproduction blob: \(blob)")
      lines.append(
        "Replay blob: try ChoiceTrace.decodeReproductionBlob(\"\(blob)\")"
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

  private static func statistics(
    record: FailureRecord,
    report: RunReport?
  ) -> RunStatistics {
    guard let report else {
      return record.statistics
    }
    return RunStatistics(
      notes: report.notes,
      events: eventLabels(from: report.events),
      targetScore: report.maxTargetScore
    )
  }

  private static func eventLabels(from events: [String: Int]) -> [String] {
    events
      .sorted { $0.key < $1.key }
      .flatMap { entry in Array(repeating: entry.key, count: entry.value) }
  }

  private static func appendStatistics(
    from statistics: RunStatistics,
    report: RunReport?,
    to lines: inout [String]
  ) {
    if !statistics.events.isEmpty {
      lines.append("Events: \(formatEvents(statistics.events))")
    }

    if !statistics.notes.isEmpty {
      lines.append("Notes: \(formatNotes(statistics.notes))")
    }

    if let targetScore = statistics.targetScore {
      lines.append("Target score: \(targetScore)")
    }

    guard let report, !report.healthWarnings.isEmpty else {
      return
    }

    let warnings = report.healthWarnings
      .map(\.check.rawValue)
      .joined(separator: ", ")
    lines.append("Health warnings: \(warnings)")
    for warning in report.healthWarnings {
      lines.append("- \(warning.message)")
    }
  }

  private static func appendMultipleFailures(
    from report: RunReport?,
    to lines: inout [String]
  ) {
    guard let report, report.failures.count > 1 else { return }
    lines.append("Distinct failures: \(report.failures.count)")
    for failure in report.failures {
      lines.append(
        "- [\(failure.phase.rawValue)] \(failure.errorMessage) "
          + "(trace entries: \(failure.traceEntryCount))"
      )
    }
  }

  private static func formatEvents(_ events: [String]) -> String {
    Dictionary(grouping: events, by: { $0 })
      .mapValues(\.count)
      .sorted { $0.key < $1.key }
      .map { "\($0.key)=\($0.value)" }
      .joined(separator: ", ")
  }

  private static func formatNotes(_ notes: [RunNote]) -> String {
    notes
      .map { "\($0.label)=\($0.value)" }
      .joined(separator: ", ")
  }
}
