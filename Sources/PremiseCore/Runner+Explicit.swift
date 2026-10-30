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
      example.value,
      data: &data,
      property: property,
      start: start
    )
    return finishExplicit(
      example,
      data: &data,
      report: &report,
      outcome: outcome
    )
  }

  private func evaluateExplicit(
    _ value: Value,
    data: inout PremiseData,
    property: @Sendable (Value, inout PremiseData) throws -> Void,
    start: Date
  ) -> ExplicitOutcome {
    do {
      try property(value, &data)
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

  private func finishExplicit(
    _ example: ExplicitExample<Value>,
    data: inout PremiseData,
    report: inout RunReport,
    outcome: ExplicitOutcome
  ) -> ExecutionFailure<Value>? {
    if case .rejected = outcome { report.recordRejected(.property) }
    report.merge(data.statistics)
    switch outcome {
    case .passed, .rejected:
      return expectedFailureIfNeeded(example: example, data: &data)
    case .failure(let message):
      guard !isExpectedToFail(example) else { return nil }
      return explicitFailure(example, data: &data, message: message)
    case .deadline(let message):
      return explicitFailure(example, data: &data, message: message)
    }
  }

  private func explicitFailure(
    _ example: ExplicitExample<Value>,
    data: inout PremiseData,
    message: String
  ) -> ExecutionFailure<Value> {
    makeFailure(
      value: example.value,
      data: &data,
      errorMessage: message,
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
      example,
      data: &data,
      report: &report,
      outcome: outcome
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
