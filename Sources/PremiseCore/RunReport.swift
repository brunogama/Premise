/// Runtime health checks that can produce non-fatal warnings.
public enum HealthCheck: String, Sendable, Codable, Hashable, CaseIterable {
  case excessiveFiltering
  case slowGeneration
  case emptySearch
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

/// Aggregated observations from all attempted examples.
public struct RunReport: Sendable, Codable, Equatable {
  /// Number of examples that reached the property body.
  public var runCount: Int

  /// Number of generated examples rejected by assumptions.
  public var rejectedCount: Int

  /// Example counts grouped by execution phase.
  public var phaseCounts: [PropertyPhase: Int]

  /// Event counts aggregated from data-aware properties.
  public var events: [String: Int]

  /// Notes emitted by data-aware properties.
  public var notes: [RunNote]

  /// Maximum target score observed during the run.
  public var maxTargetScore: Double?

  /// Non-fatal runtime quality warnings.
  public var healthWarnings: [HealthWarning]

  /// Creates an aggregated run report.
  public init(
    runCount: Int = 0,
    rejectedCount: Int = 0,
    phaseCounts: [PropertyPhase: Int] = [:],
    events: [String: Int] = [:],
    notes: [RunNote] = [],
    maxTargetScore: Double? = nil,
    healthWarnings: [HealthWarning] = []
  ) {
    self.runCount = runCount
    self.rejectedCount = rejectedCount
    self.phaseCounts = phaseCounts
    self.events = events
    self.notes = notes
    self.maxTargetScore = maxTargetScore
    self.healthWarnings = healthWarnings
  }

  /// Records one executed example for the given phase.
  public mutating func recordPhase(_ phase: PropertyPhase) {
    phaseCounts[phase, default: 0] += 1
    runCount += 1
  }

  /// Records one rejected example.
  public mutating func recordRejected() {
    rejectedCount += 1
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
