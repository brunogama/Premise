struct ShrinkContext<Value: Sendable> {
  let trace: ChoiceTrace
  let errorMessage: String
  let value: Value
  let runCount: Int
  let seed: UInt64?
  let statistics: RunStatistics
  let discovery: FailureDiscovery
}

extension ShrinkContext {
  static func from(
    failure: ExecutionFailure<Value>,
    runCount: Int,
    seed: UInt64?,
    discovery: FailureDiscovery
  ) -> Self {
    Self(
      trace: failure.record.trace,
      errorMessage: failure.record.errorMessage,
      value: failure.value,
      runCount: runCount,
      seed: seed,
      statistics: failure.record.statistics,
      discovery: discovery
    )
  }

  func unshrunk(_ failure: ExecutionFailure<Value>) -> (FailureRecord, Value) {
    var record = failure.record
    record.runCount = runCount
    record.seed = seed
    record.discovery = discovery
    return (record, failure.value)
  }
}
