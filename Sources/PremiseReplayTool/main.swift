import Foundation
import PremiseToolSupport
import PremiseCore
import PremiseDatabase

enum PremiseReplayTool {
  static func main() {
    do {
      let options = try ReplayOptions(
        arguments: Array(CommandLine.arguments.dropFirst())
      )
      if options.showHelp {
        try ToolIO.emit(Self.helpText)
        return
      }

      let summaries = try loadSummaries(options: options)
      if options.emitJSON {
        try writeJSON(summaries)
      } else {
        try ToolIO.emit(formatText(summaries))
      }
    } catch {
      reportError(error)
    }
  }

  private static func reportError(_ error: any Error) {
    _ = try? ToolIO.logError("premise-replay: \(error)")
    _ = try? ToolIO.logError(
      "Run `swift package premise-replay --help` for usage."
    )
    Foundation.exit(1)
  }

  private static func writeJSON(_ summaries: [ReplaySummary]) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let bytes = [UInt8](try encoder.encode(summaries))
    guard let text = String(bytes: bytes, encoding: .utf8) else {
      throw CocoaError(.fileReadInapplicableStringEncoding)
    }
    try ToolIO.emit(text)
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

  private static func loadSummaries(
    options: ReplayOptions
  ) throws -> [ReplaySummary] {
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

    if let artifact = try? decoder.decode(
      FailureTraceArtifact.self,
      from: data
    ) {
      return [
        ReplaySummary(
          record: artifact.record,
          valueDescription: artifact.valueDescription
        )
      ]
    }
    if let envelope = try? decoder.decode(
      PersistedFailureRecordV1.self,
      from: data
    ) {
      return [try ReplaySummary(record: PersistenceCodec.decode(envelope))]
    }
    return try decodeOther(data, decoder: decoder, source: sourceDescription)

  }

  private static func decodeOther(
    _ data: Data,
    decoder: JSONDecoder,
    source: String
  ) throws -> [ReplaySummary] {
    if let envelopes = try? decoder.decode(
      [PersistedFailureRecordV1].self,
      from: data
    ) {
      return try envelopes.map {
        try ReplaySummary(record: PersistenceCodec.decode($0))
      }
    }
    if let trace = try? decoder.decode(ChoiceTrace.self, from: data) {
      return [try ReplaySummary(trace: trace)]
    }
    if let blob = String(data: data, encoding: .utf8) {
      let trace = try ChoiceTrace.decodeReproductionBlob(blob)
      return [try ReplaySummary(trace: trace)]
    }
    throw ReplayToolError.unrecognizedTraceFile(source)
  }
}


PremiseReplayTool.main()
