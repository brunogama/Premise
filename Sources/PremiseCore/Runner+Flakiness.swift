extension Runner {
  func flakinessFailureIfNeeded(
    initialTrace: ChoiceTrace,
    errorMessage: String,
    initialValue: Value,
    runCount: Int,
    seed: UInt64?,
    statistics: RunStatistics,
    discovery: FailureDiscovery,
    replay: () -> ExecutionFailure<Value>?
  ) -> (record: FailureRecord, value: Value)? {
    flakinessFailure(
      initialTrace: initialTrace,
      errorMessage: errorMessage,
      initialValue: initialValue,
      runCount: runCount,
      seed: seed,
      statistics: statistics,
      discovery: discovery,
      replayed: replay()
    )
  }

  func flakinessFailureIfNeededAsync(
    initialTrace: ChoiceTrace,
    errorMessage: String,
    initialValue: Value,
    runCount: Int,
    seed: UInt64?,
    statistics: RunStatistics,
    discovery: FailureDiscovery,
    replay: () async -> ExecutionFailure<Value>?
  ) async -> (record: FailureRecord, value: Value)? {
    flakinessFailure(
      initialTrace: initialTrace,
      errorMessage: errorMessage,
      initialValue: initialValue,
      runCount: runCount,
      seed: seed,
      statistics: statistics,
      discovery: discovery,
      replayed: await replay()
    )
  }

  private func flakinessFailure(
    initialTrace: ChoiceTrace,
    errorMessage: String,
    initialValue: Value,
    runCount: Int,
    seed: UInt64?,
    statistics: RunStatistics,
    discovery: FailureDiscovery,
    replayed: ExecutionFailure<Value>?
  ) -> (record: FailureRecord, value: Value)? {
    guard
      let flakiness = flakiness(
        errorMessage: errorMessage,
        replayed: replayed
      )
    else {
      return nil
    }
    return flakyFailure(
      flakiness,
      trace: initialTrace,
      value: initialValue,
      runCount: runCount,
      seed: seed,
      statistics: replayed?.record.statistics ?? statistics,
      discovery: discovery
    )
  }

  private func flakiness(
    errorMessage: String,
    replayed: ExecutionFailure<Value>?
  ) -> PropertyFlakiness? {
    guard let replayed else {
      return .failureNotReproducible(originalError: errorMessage)
    }
    guard replayed.record.errorMessage != errorMessage else { return nil }
    return .failureChanged(
      originalError: errorMessage,
      replayedError: replayed.record.errorMessage
    )
  }

  private func flakyFailure(
    _ flakiness: PropertyFlakiness,
    trace: ChoiceTrace,
    value: Value,
    runCount: Int,
    seed: UInt64?,
    statistics: RunStatistics,
    discovery: FailureDiscovery
  ) -> (record: FailureRecord, value: Value) {
    (
      record: FailureRecord(
        propertyID: propertyID,
        trace: trace,
        errorMessage: String(describing: flakiness),
        runCount: runCount,
        shrinkCount: 0,
        seed: seed,
        discovery: discovery,
        statistics: statistics
      ),
      value: value
    )
  }
}
