import Foundation
import PremiseCore
import PremiseDatabase
import PremiseToolSupport

@main
struct PremiseReplayTool {
  static func main() {
    do {
      let options = try ReplayOptions(arguments: Array(CommandLine.arguments.dropFirst()))
      if options.showHelp {
        try ToolIO.emit(Self.helpText)
        return
      }

      let summaries = try loadSummaries(options: options)
      if options.emitJSON {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(summaries)
        try ToolIO.emit(String(bytes: data, encoding: .utf8) ?? "")
      } else {
        try ToolIO.emit(formatText(summaries))
      }
    } catch {
      ToolIO.logError("premise-replay: \(error)")
      ToolIO.logError("Run `swift package premise-replay --help` for usage.")
      Foundation.exit(1)
    }
  }

  private static let helpText = """
    Usage:
      swift package premise-replay <trace-path-or-blob>
      swift package premise-replay --blob <reproduction-blob>
      swift package premise-replay --json <trace-path-or-blob>

    Decodes Premise failure trace artifacts, persisted failure envelopes,
    raw ChoiceTrace JSON, or copy-paste reproduction blobs. The command
    validates the stable replay blob header and version, then prints a Swift
    snippet for decoding the trace in a property test.
    """

  private static func loadSummaries(options: ReplayOptions) throws -> [ReplaySummary] {
    if let blob = options.blob {
      let trace = try ChoiceTrace.decodeReproductionBlob(blob)
      return [try ReplaySummary(trace: trace)]
    }

    guard let input = options.input else {
      throw ReplayToolError.missingInput
    }

    if FileManager.default.fileExists(atPath: input) {
      let url = URL(fileURLWithPath: input)
      let data = try Data(contentsOf: url)
      return try decodeFile(data, sourceDescription: input)
    }

    let trace = try ChoiceTrace.decodeReproductionBlob(input)
    return [try ReplaySummary(trace: trace)]
  }

  private static func decodeFile(
    _ data: Data,
    sourceDescription: String
  ) throws -> [ReplaySummary] {
    let decoder = JSONDecoder()

    if let artifact = try? decoder.decode(FailureTraceArtifact.self, from: data) {
      return [ReplaySummary(record: artifact.record, valueDescription: artifact.valueDescription)]
    }

    if let envelope = try? decoder.decode(PersistedFailureRecordV1.self, from: data) {
      return [try ReplaySummary(record: PersistenceCodec.decode(envelope))]
    }

    if let envelopes = try? decoder.decode([PersistedFailureRecordV1].self, from: data) {
      return try envelopes.map { envelope in
        try ReplaySummary(record: PersistenceCodec.decode(envelope))
      }
    }

    if let trace = try? decoder.decode(ChoiceTrace.self, from: data) {
      return [try ReplaySummary(trace: trace)]
    }

    if let blob = String(data: data, encoding: .utf8) {
      let trace = try ChoiceTrace.decodeReproductionBlob(blob)
      return [try ReplaySummary(trace: trace)]
    }

    throw ReplayToolError.unrecognizedTraceFile(sourceDescription)
  }

  private static func formatText(_ summaries: [ReplaySummary]) -> String {
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

    if let propertyID = summary.propertyID {
      if let functionName = propertyID.functionName {
        lines.append("Property: \(propertyID.fileID) \(functionName)#\(propertyID.line)")
      } else {
        lines.append("Property: \(propertyID.fileID)#\(propertyID.line)")
      }
      lines.append("Strategy: \(propertyID.strategyLabel)")
    } else {
      lines.append("Property: unavailable")
    }

    if let discovery = summary.discovery {
      lines.append("Failure kind: \(discovery.rawValue)")
    }
    if let errorMessage = summary.errorMessage {
      lines.append("Error: \(errorMessage)")
    }
    if let valueDescription = summary.valueDescription {
      lines.append("Value: \(valueDescription)")
    }
    if let runCount = summary.runCount, let shrinkCount = summary.shrinkCount {
      lines.append("Runs: \(runCount), Shrinks: \(shrinkCount)")
    }
    if let seed = summary.seed {
      lines.append("Seed: \(seed)")
    }

    lines.append("Trace entries: \(summary.traceEntryCount)")
    lines.append("Trace spans: \(summary.traceSpanCount)")
    lines.append("Reproduction blob: \(summary.reproductionBlob)")
    lines.append("Swift decode:")
    lines.append(
      "let trace = try ChoiceTrace.decodeReproductionBlob(\"\(summary.reproductionBlob)\")"
    )
    lines.append("Pass `trace` to `Runner.runDetailed(..., replayTraces: [trace])`.")
    return lines.joined(separator: "\n")
  }
}

private struct ReplayOptions {
  var emitJSON = false
  var showHelp = false
  var blob: String?
  var input: String?

  init(arguments: [String]) throws {
    var iterator = arguments.makeIterator()
    while let argument = iterator.next() {
      switch argument {
      case "--help", "-h":
        showHelp = true

      case "--json":
        emitJSON = true

      case "--blob":
        guard let next = iterator.next() else {
          throw ReplayToolError.missingBlob
        }
        blob = next

      default:
        guard input == nil else {
          throw ReplayToolError.tooManyInputs
        }
        input = argument
      }
    }
  }
}

private struct ReplaySummary: Sendable, Codable, Equatable {
  var propertyID: PropertyIdentity?
  var errorMessage: String?
  var valueDescription: String?
  var runCount: Int?
  var shrinkCount: Int?
  var seed: UInt64?
  var discovery: FailureDiscovery?
  var traceEntryCount: Int
  var traceSpanCount: Int
  var reproductionBlob: String

  init(record: FailureRecord, valueDescription: String? = nil) {
    self.propertyID = record.propertyID
    self.errorMessage = record.errorMessage
    self.valueDescription = valueDescription
    self.runCount = record.runCount
    self.shrinkCount = record.shrinkCount
    self.seed = record.seed
    self.discovery = record.discovery
    self.traceEntryCount = record.trace.entries.count
    self.traceSpanCount = record.trace.spans.count
    self.reproductionBlob = (try? record.trace.reproductionBlob()) ?? ""
  }

  init(trace: ChoiceTrace) throws {
    self.propertyID = nil
    self.errorMessage = nil
    self.valueDescription = nil
    self.runCount = nil
    self.shrinkCount = nil
    self.seed = nil
    self.discovery = nil
    self.traceEntryCount = trace.entries.count
    self.traceSpanCount = trace.spans.count
    self.reproductionBlob = try trace.reproductionBlob()
  }
}

private enum ReplayToolError: Error, CustomStringConvertible {
  case missingInput
  case missingBlob
  case tooManyInputs
  case unrecognizedTraceFile(String)

  var description: String {
    switch self {
    case .missingInput:
      return "missing trace path or reproduction blob"

    case .missingBlob:
      return "--blob requires a reproduction blob argument"

    case .tooManyInputs:
      return "expected at most one trace path or reproduction blob"

    case .unrecognizedTraceFile(let path):
      return "could not decode trace file at \(path)"
    }
  }
}
