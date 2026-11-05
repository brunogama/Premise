import Foundation

extension Runner {
  func executeExplicit(
    _ example: ExplicitExample<Value>,
    property: @Sendable (Value, inout PremiseData) throws -> Void,
    report: inout RunReport
  ) -> ExecutionFailure<Value>? {
    var data = PremiseData(
      provider: PseudoRandomProvider(seed: 0, maxDraws: config.maxDrawsPerRun)
    )
    report.recordPhase(.explicit)
    let start = Date()

    let outcome = evaluateExplicit(
      (value: example.value, start: start),
      data: &data,
      property: property
    )
    return finishExplicit(
      (example: example, outcome: outcome),
      data: &data,
      report: &report
    )
  }

  private func evaluateExplicit(
    _ execution: (value: Value, start: Date),
    data: inout PremiseData,
    property: @Sendable (Value, inout PremiseData) throws -> Void
  ) -> ExplicitOutcome {
    do {
      try property(execution.value, &data)
      if let message = deadlineFailure(since: execution.start) {
        return .deadline(message)
      }
      return .passed
    } catch is PremiseRejection {
      return .rejected
    } catch {
      return .failure(String(describing: error))
    }
  }

  private func finishExplicit(
    _ execution: (example: ExplicitExample<Value>, outcome: ExplicitOutcome),
    data: inout PremiseData,
    report: inout RunReport
  ) -> ExecutionFailure<Value>? {
    if case .rejected = execution.outcome { report.recordRejected(.property) }
    report.merge(data.statistics)
    switch execution.outcome {
    case .passed, .rejected:
      return expectedFailureIfNeeded(example: execution.example, data: &data)
    case .failure(let message):
      guard !isExpectedToFail(execution.example) else { return nil }
      return explicitFailure(execution.example, data: &data, message: message)
    case .deadline(let message):
      return explicitFailure(execution.example, data: &data, message: message)
    }
  }

  private func explicitFailure(
    _ example: ExplicitExample<Value>,
    data: inout PremiseData,
    message: String
  ) -> ExecutionFailure<Value> {
    makeFailure(
      failure: (example.value, message),
      data: &data,
      runCount: 0
    )
  }

  func executeExplicitAsync(
    _ example: ExplicitExample<Value>,
    property: @escaping @Sendable (Value) async throws -> Void,
    report: inout RunReport
  ) async -> ExecutionFailure<Value>? {
    var data = PremiseData(
      provider: PseudoRandomProvider(seed: 0, maxDraws: config.maxDrawsPerRun)
    )
    report.recordPhase(.explicit)
    let start = Date()

    let outcome = await evaluateExplicitAsync(
      example.value,
      property: property,
      start: start
    )
    return finishExplicit(
      (example: example, outcome: outcome),
      data: &data,
      report: &report
    )
  }

  private func evaluateExplicitAsync(
    _ value: Value,
    property: @Sendable (Value) async throws -> Void,
    start: Date
  ) async -> ExplicitOutcome {
    do {
      try await property(value)
      if let message = deadlineFailure(since: start) {
        return .deadline(message)
      }
      return .passed
    } catch is PremiseRejection {
      return .rejected
    } catch {
      return .failure(String(describing: error))
    }
  }
}
