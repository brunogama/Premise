struct ExecutionFailure<Value: Sendable> {
  let record: FailureRecord
  let value: Value
}
