/// Runtime health checks that can produce non-fatal warnings.
public enum HealthCheck: String, Sendable, Codable, Hashable, CaseIterable {
  case excessiveFiltering
  case slowGeneration
  case emptySearch
}

/// Distinguishes where an example was rejected.
public enum RejectionKind: String, Sendable, Codable, Hashable, CaseIterable {
  /// The strategy could not draw a satisfying value.
  case draw

  /// The property body rejected the example after observing generated data.
  case property
}

/// Errors raised when a property failure cannot be reproduced reliably.
public enum PropertyFlakiness: Error, Sendable, Equatable, CustomStringConvertible {
  /// A failure was observed once, but replaying its trace did not fail again.
  case failureNotReproducible(originalError: String)

  /// Replaying a failing trace produced a different error.
  case failureChanged(originalError: String, replayedError: String)

  public var description: String {
    switch self {
    case .failureNotReproducible(let originalError):
      return "Flaky failure: trace did not reproduce original error: \(originalError)"
    case .failureChanged(let originalError, let replayedError):
      return "Flaky failure: replay changed from `\(originalError)` to `\(replayedError)`."
    }
  }
}

/// A non-fatal warning about property execution quality.
public struct HealthWarning: Sendable, Codable, Equatable {
  /// Health check that produced the warning.
  public let check: HealthCheck

  /// Human-readable warning message.
  public let message: String

  /// Creates a health warning.
  public init(check: HealthCheck, message: String) {
    self.check = check
    self.message = message
  }
}

/// Summary of one distinct failure observed during a run.
public struct RunFailureSummary: Sendable, Codable, Equatable {
  /// Phase that observed the failure.
  public let phase: PropertyPhase

  /// Error message captured from the failing property.
  public let errorMessage: String

  /// Number of entries in the minimized trace.
  public let traceEntryCount: Int

  /// Number of shrink steps applied to this failure.
  public let shrinkCount: Int

  /// Whether the failure was newly found or replayed from corpus.
  public let discovery: FailureDiscovery

  /// Creates a compact failure summary.
  public init(phase: PropertyPhase, record: FailureRecord) {
    self.phase = phase
    self.errorMessage = record.errorMessage
    self.traceEntryCount = record.trace.entries.count
    self.shrinkCount = record.shrinkCount
    self.discovery = record.discovery
  }
}

/// Aggregated observations from all attempted examples.
public struct RunReport: Sendable, Codable, Equatable {
  /// Number of examples that reached the property body.
  public var runCount: Int

  /// Number of generated examples rejected by assumptions.
  public var rejectedCount: Int

  /// Rejected examples grouped by where the rejection occurred.
  public var rejectionCounts: [RejectionKind: Int]

  /// Example counts grouped by execution phase.
  public var phaseCounts: [PropertyPhase: Int]

  /// Event counts aggregated from data-aware properties.
  public var events: [String: Int]

  /// Notes emitted by data-aware properties.
  public var notes: [RunNote]

  /// Maximum target score observed during the run.
  public var maxTargetScore: Double?

  /// Distinct failures observed when multiple-bug reporting is enabled.
  public var failures: [RunFailureSummary]

  /// Non-fatal runtime quality warnings.
  public var healthWarnings: [HealthWarning]

  /// Creates an aggregated run report.
  public init(
    runCount: Int = 0,
    rejectedCount: Int = 0,
    rejectionCounts: [RejectionKind: Int] = [:],
    phaseCounts: [PropertyPhase: Int] = [:],
    events: [String: Int] = [:],
    notes: [RunNote] = [],
    maxTargetScore: Double? = nil,
    failures: [RunFailureSummary] = [],
    healthWarnings: [HealthWarning] = []
  ) {
    self.runCount = runCount
    self.rejectedCount = rejectedCount
    self.rejectionCounts = rejectionCounts
    self.phaseCounts = phaseCounts
    self.events = events
    self.notes = notes
    self.maxTargetScore = maxTargetScore
    self.failures = failures
    self.healthWarnings = healthWarnings
  }

  /// Records one executed example for the given phase.
  public mutating func recordPhase(_ phase: PropertyPhase) {
    phaseCounts[phase, default: 0] += 1
    runCount += 1
  }

  /// Records one rejected example.
  public mutating func recordRejected(_ kind: RejectionKind = .draw) {
    rejectedCount += 1
    rejectionCounts[kind, default: 0] += 1
  }

  /// Records one distinct failure observed in the given phase.
  public mutating func recordFailure(_ record: FailureRecord, phase: PropertyPhase) {
    let summary = RunFailureSummary(phase: phase, record: record)
    guard !failures.contains(summary) else { return }
    failures.append(summary)
  }

  /// Merges per-example statistics into this report.
  public mutating func merge(_ statistics: RunStatistics) {
    for event in statistics.events {
      events[event, default: 0] += 1
    }
    var reportNotes = statistics.notes
    if let score = statistics.targetScore {
      if let targetNoteIndex = reportNotes.lastIndex(where: { $0.value == String(score) }) {
        reportNotes.remove(at: targetNoteIndex)
      }
      maxTargetScore = max(maxTargetScore ?? score, score)
    }
    notes.append(contentsOf: reportNotes)
  }

  /// Appends enabled health warnings based on accumulated counts.
  public mutating func applyHealthChecks(
    enabledChecks: [HealthCheck],
    maxRuns: Int
  ) {
    guard maxRuns > 0 else { return }

    if enabledChecks.contains(.emptySearch), runCount == 0 {
      healthWarnings.append(
        HealthWarning(
          check: .emptySearch,
          message: "No valid examples were executed."
        )
      )
    }

    if enabledChecks.contains(.excessiveFiltering) {
      let attempts = runCount + rejectedCount
      if attempts >= 20, rejectedCount * 2 > attempts {
        healthWarnings.append(
          HealthWarning(
            check: .excessiveFiltering,
            message: "More than half of generated examples were rejected."
          )
        )
      }
    }
  }
}

/// Detailed result used by adapters that need diagnostics beyond pass/fail.
public enum DetailedRunResult<Value: Sendable>: Sendable {
  case passed(RunReport)
  case failure(FailureRecord, value: Value, report: RunReport)
}

public extension DetailedRunResult {
  var compact: RunResult<Value> {
    switch self {
    case .passed(let report):
      return .passed(runs: report.runCount)
    case .failure(let record, let value, report: _):
      return .failure(record, value: value)
    }
  }
}
