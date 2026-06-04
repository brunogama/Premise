/// Runtime health checks that can produce non-fatal warnings.
public enum HealthCheck: String, Sendable, Codable, Hashable, CaseIterable {
  case excessiveFiltering
  case slowGeneration
  case emptySearch
}

/// A non-fatal warning about property execution quality.
public struct HealthWarning: Sendable, Codable, Equatable {
  public let check: HealthCheck
  public let message: String

  public init(check: HealthCheck, message: String) {
    self.check = check
    self.message = message
  }
}

/// Aggregated observations from all attempted examples.
public struct RunReport: Sendable, Codable, Equatable {
  public var runCount: Int
  public var rejectedCount: Int
  public var phaseCounts: [PropertyPhase: Int]
  public var events: [String: Int]
  public var notes: [RunNote]
  public var maxTargetScore: Double?
  public var healthWarnings: [HealthWarning]

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

  public mutating func recordPhase(_ phase: PropertyPhase) {
    phaseCounts[phase, default: 0] += 1
    runCount += 1
  }

  public mutating func recordRejected() {
    rejectedCount += 1
  }

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
    case .failure(let record, value: let value, report: _):
      return .failure(record, value: value)
    }
  }
}
