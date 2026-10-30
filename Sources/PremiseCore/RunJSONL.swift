import Foundation


/// One structured JSON Lines event emitted by a property run.
public struct RunJSONLEvent: Sendable, Codable, Equatable {
  /// JSONL event schema version.
  public var formatVersion: Int

  /// Stable event name for downstream parsers.
  public var event: String

  /// Wall-clock time when this event was emitted.
  public var timestamp: Date

  /// Property identity that produced the event.
  public var propertyID: PropertyIdentity

  /// Pass/fail outcome.
  public var outcome: RunJSONLOutcome

  /// Number of examples that reached the property body.
  public var runCount: Int

  /// Number of rejected examples.
  public var rejectedCount: Int

  /// Rejected examples grouped by rejection source.
  public var rejectionCounts: [String: Int]

  /// Executed examples grouped by phase.
  public var phaseCounts: [String: Int]

  /// Aggregated event labels from the property body.
  public var events: [String: Int]

  /// Notes emitted by data-aware properties.
  public var notes: [RunNote]

  /// Highest target score observed during the run.
  public var maxTargetScore: Double?

  /// Distinct failures observed when multiple-bug reporting was enabled.
  public var failures: [RunFailureSummary]

  /// Non-fatal health warnings emitted by the run.
  public var healthWarnings: [HealthWarning]

  /// Failure metadata when `outcome == .failed`.
  public var failure: RunJSONLFailure?

  /// Creates a JSONL event from a detailed run result.
  public init<Value: Sendable>(
    propertyID: PropertyIdentity,
    result: DetailedRunResult<Value>,
    timestamp: Date = Date()
  ) {
    self.formatVersion = 1
    self.event = "premise.run"
    self.timestamp = timestamp
    self.propertyID = propertyID

    let report = result.jsonlReport
    self.failure = result.jsonlFailure
    self.outcome = failure == nil ? .passed : .failed

    self.runCount = report.runCount
    self.rejectedCount = report.rejectedCount
    self.rejectionCounts = report.rejectionCounts.stringKeyed()
    self.phaseCounts = report.phaseCounts.stringKeyed()
    self.events = report.events
    self.notes = report.notes
    self.maxTargetScore = report.maxTargetScore
    self.failures = report.failures
    self.healthWarnings = report.healthWarnings
  }

  /// Encodes the event as a single JSON line without a trailing newline.
  public func encodedLine() throws -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(self)
    guard let line = String(data: data, encoding: .utf8) else {
      throw ChoiceTraceBlobError.malformed("JSONL event is not valid UTF-8")
    }
    return line
  }
}


private extension Dictionary where Key == RejectionKind, Value == Int {
  func stringKeyed() -> [String: Int] {
    [String: Int](uniqueKeysWithValues: map { ($0.key.rawValue, $0.value) })
  }
}

private extension Dictionary where Key == PropertyPhase, Value == Int {
  func stringKeyed() -> [String: Int] {
    [String: Int](uniqueKeysWithValues: map { ($0.key.rawValue, $0.value) })
  }
}

private extension DetailedRunResult {
  var jsonlReport: RunReport {
    switch self {
    case .passed(let report), .failure(_, value: _, let report):
      return report
    }
  }

  var jsonlFailure: RunJSONLFailure? {
    guard case .failure(let record, value: _, report: _) = self else {
      return nil
    }
    return RunJSONLFailure(record: record)
  }
}
