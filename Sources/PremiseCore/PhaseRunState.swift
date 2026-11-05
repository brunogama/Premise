import Foundation

struct PhaseRunState<Value: Sendable> {
  let phase: PropertyPhase
  let seed: UInt64
  let deadline: Date?
  var corpus = TargetedTraceCorpus()
  var seenFailures = Set<String>()
  var firstFailure: (record: FailureRecord, value: Value)?

  func mutation(index: Int) -> ChoiceTrace? {
    guard phase == .target else { return nil }
    return corpus.mutation(seed: seed, iteration: index)
  }

  mutating func record(
    _ attempt: ExecutionAttempt<Value>,
    report: inout RunReport
  ) {
    switch attempt {
    case .passed(let statistics, let trace):
      report.recordPhase(phase)
      report.merge(statistics)
      recordTarget(trace: trace, statistics: statistics)
    case .rejected(let kind, let statistics, let trace):
      report.recordRejected(kind)
      report.merge(statistics)
      recordTarget(trace: trace, statistics: statistics)
    case .failure:
      break
    }
  }

  mutating func recordFailure(
    _ record: FailureRecord,
    report: inout RunReport
  ) -> Bool {
    let key = [
      record.errorMessage,
      record.discovery.rawValue,
      String(record.trace.entries.count),
    ].joined(separator: "#")
    guard seenFailures.insert(key).inserted else { return false }
    report.recordFailure(record, phase: phase)
    return true
  }

  private mutating func recordTarget(
    trace: ChoiceTrace,
    statistics: RunStatistics
  ) {
    guard phase == .target else { return }
    corpus.record(trace: trace, statistics: statistics)
  }
}
