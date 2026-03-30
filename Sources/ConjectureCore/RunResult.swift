public enum RunResult<Value: Sendable>: Sendable {
    case passed(runs: Int)
    case failure(FailureRecord, value: Value)
}
