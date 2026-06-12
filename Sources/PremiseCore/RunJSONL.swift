import Foundation

/// Pass/fail outcome recorded in a JSON Lines run event.
public enum RunJSONLOutcome: String, Sendable, Codable, Equatable {
  case passed
  case failed
}

/// Failure metadata recorded in a JSON Lines run event.
public struct RunJSONLFailure: Sendable, Codable, Equatable {
  /// Error message captured from the failing property.
  public var errorMessage: String

  /// Number of entries in the minimized replay trace.
  public var traceEntryCount: Int

  /// Number of successful shrink steps applied to the failure.
  public var shrinkCount: Int

  /// Base seed that discovered the failure, when available.
  public var seed: UInt64?

  /// Whether the failure was newly found or replayed from a corpus.
  public var discovery: FailureDiscovery

  /// Copy-paste replay blob for tooling and diagnostics.
  public var reproductionBlob: String?

  public init(record: FailureRecord) {
    self.errorMessage = record.errorMessage
    self.traceEntryCount = record.trace.entries.count
    self.shrinkCount = record.shrinkCount
    self.seed = record.seed
    self.discovery = record.discovery
    self.reproductionBlob = try? record.trace.reproductionBlob()
  }
}

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

    let report: RunReport
    switch result {
    case .passed(let passedReport):
      self.outcome = .passed
      self.failure = nil
      report = passedReport

    case .failure(let record, value: _, report: let failureReport):
      self.outcome = .failed
      self.failure = RunJSONLFailure(record: record)
      report = failureReport
    }

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

/// Appends structured run events to a JSON Lines file.
public enum RunJSONLWriter {
  private static let appendLock = NSLock()

  /// Appends one event as a single line, creating parent directories as needed.
  public static func append(_ event: RunJSONLEvent, to fileURL: URL) throws {
    let line = try event.encodedLine() + "\n"
    guard let data = line.data(using: .utf8) else {
      throw ChoiceTraceBlobError.malformed("JSONL event is not valid UTF-8")
    }

    appendLock.lock()
    defer { appendLock.unlock() }

    let directory = fileURL.deletingLastPathComponent()
    if !directory.path.isEmpty {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
    }

    if FileManager.default.fileExists(atPath: fileURL.path) {
      let handle = try FileHandle(forWritingTo: fileURL)
      defer { try? handle.close() }
      try handle.seekToEnd()
      try handle.write(contentsOf: data)
    } else {
      try data.write(to: fileURL, options: [.atomic])
    }
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
