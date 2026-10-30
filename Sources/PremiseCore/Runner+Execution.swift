import Foundation

extension Runner {
  func executeAttempt(
    trace: ChoiceTrace,
    property: @Sendable (Value, inout PremiseData) throws -> Void
  ) -> ExecutionAttempt<Value> {
    let provider = ReplayProvider(trace: trace)
    return executeAttempt(provider: provider, property: property)
  }

  func executeAttempt(
    provider: some PrimitiveProvider,
    property: @Sendable (Value, inout PremiseData) throws -> Void
  ) -> ExecutionAttempt<Value> {
    var data = PremiseData(provider: provider)

    let drawnValue: Value
    do {
      drawnValue = try strategy.draw(&data)
    } catch {
      return .rejected(.draw, data.statistics, data.snapshot())
    }

    return executePropertyAttempt(
      drawnValue,
      data: &data,
      property: property,
      start: Date()
    )
  }

  private func executePropertyAttempt(
    _ value: Value,
    data: inout PremiseData,
    property: @Sendable (Value, inout PremiseData) throws -> Void,
    start: Date
  ) -> ExecutionAttempt<Value> {
    do {
      try property(value, &data)
      if let message = deadlineFailure(since: start) {
        return attemptFailure(value, data: &data, message: message)
      }
      return .passed(data.statistics, data.snapshot())
    } catch is PremiseRejection {
      return .rejected(.property, data.statistics, data.snapshot())
    } catch {
      return attemptFailure(
        value,
        data: &data,
        message: String(describing: error)
      )
    }
  }

  private func attemptFailure(
    _ value: Value,
    data: inout PremiseData,
    message: String
  ) -> ExecutionAttempt<Value> {
    .failure(
      makeFailure(
        value: value,
        data: &data,
        errorMessage: message,
        runCount: 1
      )
    )
  }


  func executeAttemptAsync(
    trace: ChoiceTrace,
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> ExecutionAttempt<Value> {
    let provider = ReplayProvider(trace: trace)
    return await executeAttemptAsync(provider: provider, property: property)
  }

  func executeAttemptAsync(
    provider: some PrimitiveProvider,
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> ExecutionAttempt<Value> {
    var data = PremiseData(provider: provider)

    let drawnValue: Value
    do {
      drawnValue = try strategy.draw(&data)
    } catch {
      return .rejected(.draw, data.statistics, data.snapshot())
    }

    return await executePropertyAttemptAsync(
      drawnValue,
      data: &data,
      property: property,
      start: Date()
    )
  }

  private func executePropertyAttemptAsync(
    _ value: Value,
    data: inout PremiseData,
    property: @Sendable (Value) async throws -> Void,
    start: Date
  ) async -> ExecutionAttempt<Value> {
    do {
      try await property(value)
      if let message = deadlineFailure(since: start) {
        return attemptFailure(value, data: &data, message: message)
      }
      return .passed(data.statistics, data.snapshot())
    } catch is PremiseRejection {
      return .rejected(.property, data.statistics, data.snapshot())
    } catch {
      return attemptFailure(
        value,
        data: &data,
        message: String(describing: error)
      )
    }
  }

  /// Executes a single run from a stored trace.
  func executeSingle(
    trace: ChoiceTrace,
    property: @Sendable (Value, inout PremiseData) throws -> Void
  ) -> ExecutionFailure<Value>? {
    let provider = ReplayProvider(trace: trace)
    return executeSingle(provider: provider, property: property)
  }

  /// Executes a single run from a stored trace.
  func executeSingle(
    trace: ChoiceTrace,
    property: @Sendable (Value) throws -> Void
  ) -> ExecutionFailure<Value>? {
    executeSingle(trace: trace) { value, _ in
      try property(value)
    }
  }

  /// Executes a single run from a provider, returning a failure or nil.
  func executeSingle(
    provider: some PrimitiveProvider,
    property: @Sendable (Value, inout PremiseData) throws -> Void
  ) -> ExecutionFailure<Value>? {
    if case .failure(let failure) = executeAttempt(
      provider: provider,
      property: property
    ) {
      return failure
    }
    return nil
  }

  /// Executes a single run from a provider, returning a failure or nil.
  ///
  /// Draw-phase errors (including ``StrategyError``) are treated as
  /// "invalid input — skip this run" and return nil.  Only property-phase
  /// errors are reported as failures.
  func executeSingle(
    provider: some PrimitiveProvider,
    property: @Sendable (Value) throws -> Void
  ) -> ExecutionFailure<Value>? {
    executeSingle(provider: provider) { value, _ in
      try property(value)
    }
  }

  /// Executes a single async run from a stored trace.
  func executeSingleAsync(
    trace: ChoiceTrace,
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> ExecutionFailure<Value>? {
    let provider = ReplayProvider(trace: trace)
    return await executeSingleAsync(provider: provider, property: property)
  }

  /// Executes a single async run from a provider, returning a failure or nil.
  func executeSingleAsync(
    provider: some PrimitiveProvider,
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> ExecutionFailure<Value>? {
    var data = PremiseData(provider: provider)

    let drawnValue: Value
    do {
      drawnValue = try strategy.draw(&data)
    } catch {
      return nil
    }

    guard
      let errorMessage = await singleAsyncError(
        drawnValue,
        property: property,
        start: Date()
      )
    else { return nil }
    return makeFailure(
      value: drawnValue,
      data: &data,
      errorMessage: errorMessage,
      runCount: 1
    )
  }

  private func singleAsyncError(
    _ value: Value,
    property: @Sendable (Value) async throws -> Void,
    start: Date
  ) async -> String? {
    do {
      try await property(value)
      return deadlineFailure(since: start)
    } catch is PremiseRejection {
      return nil
    } catch {
      return String(describing: error)
    }
  }
}
