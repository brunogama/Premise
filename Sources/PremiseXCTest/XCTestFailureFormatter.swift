import PremiseCore

/// Formats a property failure into a human-readable diagnostic string
/// for XCTest output containing the counterexample, run/shrink counts,
/// and replay instructions.
enum XCTestFailureFormatter {
  /// Builds a diagnostic message from a property failure.
  static func format<Value>(
    value: Value,
    context: XCTestFailureContext
  ) -> String {
    let record = context.record
    let report = context.report
    var lines = [
      "Property failed: \(location(context.propertyID))",
      "Failure kind: \(record.discovery.rawValue)",
      "Minimal counterexample: \(prettyPrint(value))",
      "Error: \(record.errorMessage)",
      "Runs: \(record.runCount), Shrinks: \(record.shrinkCount)",
      "Trace entries: \(record.trace.entries.count)",
    ]
    appendStatistics(
      from: statistics(record: record, report: report),
      report: report,
      to: &lines
    )
    appendMultipleFailures(from: report, to: &lines)
    appendReplay(context: context, to: &lines)
    return lines.joined(separator: "\n")
  }

  private static func location(_ propertyID: PropertyIdentity) -> String {
    guard let function = propertyID.functionName else {
      return "\(propertyID.fileID)#\(propertyID.line)"
    }
    return "\(propertyID.fileID) \(function)#\(propertyID.line)"
  }

  private static func appendReplay(
    context: XCTestFailureContext,
    to lines: inout [String]
  ) {
    let record = context.record
    if let seed = record.seed {
      lines.append("Seed to reproduce: \(seed)")
      lines.append("Replay: config: PropertyConfig(seed: \(seed))")
    } else {
      lines.append(
        "Replay: use the persisted trace from .premise/examples "
          + "or an exported JSON trace artifact."
      )
    }
    if context.includeReproductionBlob,
      let blob = try? record.trace.reproductionBlob()
    {
      lines.append("Reproduction blob: \(blob)")
      lines.append(
        "Replay blob: try ChoiceTrace.decodeReproductionBlob(\"\(blob)\")"
      )
    }
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
