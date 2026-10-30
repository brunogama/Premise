extension PremiseReplayTool {
  static func formatText(_ summaries: [ReplaySummary]) -> String {
    summaries.enumerated()
      .map { index, summary in
        formatText(summary, index: index, total: summaries.count)
      }
      .joined(separator: "\n\n")
  }

  private static func formatText(
    _ summary: ReplaySummary,
    index: Int,
    total: Int
  ) -> String {
    var lines: [String] = []
    let suffix = total > 1 ? " \(index + 1)/\(total)" : ""
    lines.append("Premise replay trace\(suffix)")

    lines.append(contentsOf: propertyLines(summary))
    lines.append(contentsOf: failureLines(summary))

    lines.append("Trace entries: \(summary.traceEntryCount)")
    lines.append("Trace spans: \(summary.traceSpanCount)")
    lines.append("Reproduction blob: \(summary.reproductionBlob)")
    lines.append("Swift decode:")
    lines.append(
      "let trace = try ChoiceTrace.decodeReproductionBlob(\""
        + "\(summary.reproductionBlob)\")"
    )
    lines.append(
      "Pass `trace` to `Runner.runDetailed(..., replayTraces: [trace])`."
    )
    return lines.joined(separator: "\n")
  }

  private static func propertyLines(_ summary: ReplaySummary) -> [String] {
    guard let propertyID = summary.propertyID else {
      return ["Property: unavailable"]
    }
    let name = propertyID.functionName.map { " \($0)" } ?? ""
    let property = "Property: \(propertyID.fileID)\(name)#\(propertyID.line)"
    return [property, "Strategy: \(propertyID.strategyLabel)"]
  }

  private static func failureLines(_ summary: ReplaySummary) -> [String] {
    var lines: [String] = []
    if let discovery = summary.discovery {
      lines.append("Failure kind: \(discovery.rawValue)")
    }
    if let message = summary.errorMessage { lines.append("Error: \(message)") }
    if let value = summary.valueDescription { lines.append("Value: \(value)") }
    if let runs = summary.runCount, let shrinks = summary.shrinkCount {
      lines.append("Runs: \(runs), Shrinks: \(shrinks)")
    }
    if let seed = summary.seed { lines.append("Seed: \(seed)") }
    return lines
  }
}
