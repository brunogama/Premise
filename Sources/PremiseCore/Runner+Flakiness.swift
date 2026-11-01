extension Runner {
  func flakinessFailureIfNeeded(
    context: ShrinkContext<Value>,
    replay: () -> ExecutionFailure<Value>?
  ) -> (record: FailureRecord, value: Value)? {
    flakinessFailure(
      context: context,
      replayed: replay()
    )
  }

  func flakinessFailureIfNeededAsync(
    context: ShrinkContext<Value>,
    replay: () async -> ExecutionFailure<Value>?
  ) async -> (record: FailureRecord, value: Value)? {
    flakinessFailure(
      context: context,
      replayed: await replay()
    )
  }

  private func flakinessFailure(
    context: ShrinkContext<Value>,
    replayed: ExecutionFailure<Value>?
  ) -> (record: FailureRecord, value: Value)? {
    guard
      let flakiness = flakiness(
        errorMessage: context.errorMessage,
        replayed: replayed
      )
    else {
      return nil
    }
    return flakyFailure(
      flakiness,
      context: context,
      statistics: replayed?.record.statistics ?? context.statistics
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
    context: ShrinkContext<Value>,
    statistics: RunStatistics
  ) -> (record: FailureRecord, value: Value) {
    (
      record: FailureRecord(
        propertyID: propertyID,
        trace: context.trace,
        errorMessage: String(describing: flakiness),
        runCount: context.runCount,
        shrinkCount: 0,
        seed: context.seed,
        discovery: context.discovery,
        statistics: statistics
      ),
      value: context.value
    )
  }
}
