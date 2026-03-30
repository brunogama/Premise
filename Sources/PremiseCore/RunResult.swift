public enum RunResult<Value: Sendable>: Sendable {
  case passed(runs: Int)
  case failure(FailureRecord, value: Value)
}

// MARK: - Convenience accessors

public extension RunResult {
  /// `true` when all runs passed.
  var isPassed: Bool {
    if case .passed = self { return true }
    return false
  }

  /// `true` when a counterexample was found.
  var isFailure: Bool {
    if case .failure = self { return true }
    return false
  }

  /// The minimized counterexample, or `nil` when all runs passed.
  var failureValue: Value? {
    if case .failure(_, value: let v) = self { return v }
    return nil
  }

  /// The failure record containing trace, seed, shrink count, etc.
  var failureRecord: FailureRecord? {
    if case .failure(let r, value: _) = self { return r }
    return nil
  }

  /// The number of runs executed.
  var runCount: Int {
    switch self {
    case .passed(let runs): return runs
    case .failure(let record, value: _): return record.runCount
    }
  }
}
