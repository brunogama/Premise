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
