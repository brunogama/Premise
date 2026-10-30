import Foundation
import PremiseCore
import PremiseDatabase

func runFuzzOneInput<Value: Sendable>(
  request: FuzzRunRequest,
  strategy: Strategy<Value>,
  property: @escaping @Sendable (Value) async throws -> Void
) async throws -> FuzzRunResult {
  let bytes = Array(request.input)
  var data = PremiseData(provider: FuzzInputProvider(bytes: bytes))

  let value: Value
  do {
    value = try strategy.draw(&data)
  } catch {
    return rejectedFuzzResult(
      data: data,
      count: bytes.count,
      reason: String(describing: error)
    )
  }

  guard data.status != .exhausted else {
    return fuzzResult(.exhausted, data: data, count: bytes.count)
  }

  return try await runFuzzProperty(request: request, data: data) {
    try await property(value)
  }
}

private func fuzzResult(
  _ outcome: FuzzOutcome,
  data: PremiseData,
  count: Int
) -> FuzzRunResult {
  var data = data
  return FuzzRunResult(
    outcome: outcome,
    inputByteCount: count,
    trace: data.snapshot()
  )
}

private func rejectedFuzzResult(
  data: PremiseData,
  count: Int,
  reason: String
) -> FuzzRunResult {
  var data = data
  return FuzzRunResult(
    outcome: .rejected,
    inputByteCount: count,
    trace: data.snapshot(),
    rejectionReason: reason
  )
}

private func runFuzzProperty(
  request: FuzzRunRequest,
  data: PremiseData,
  property: () async throws -> Void
) async throws -> FuzzRunResult {
  var data = data
  do {
    try await property()
    return fuzzResult(.passed, data: data, count: request.input.count)
  } catch is PremiseRejection {
    return rejectedFuzzResult(
      data: data,
      count: request.input.count,
      reason: "property rejected fuzz input"
    )
  } catch {
    let failure = FuzzFailure(
      input: Array(request.input),
      propertyID: request.config.propertyID,
      trace: data.snapshot(),
      underlyingDescription: String(describing: error)
    )
    try await persist(failure: failure, config: request.config)
    throw failure
  }
}

private func persist(
  failure: FuzzFailure,
  config: FuzzConfig
) async throws {
  guard config.saveFailures, let directory = config.databaseDirectory else {
    return
  }

  let record = FailureRecord(
    propertyID: config.propertyID,
    trace: failure.trace,
    errorMessage: failure.description,
    runCount: 1,
    shrinkCount: 0,
    seed: nil,
    discovery: .newFailure,
    statistics: fuzzStatistics(input: failure.input)
  )
  try await FileBackedDatabase(rootDirectory: directory).save(record)
}

private func fuzzStatistics(input: [UInt8]) -> RunStatistics {
  RunStatistics(
    notes: [
      RunNote(
        label: "fuzzInputBase64",
        value: Data(input).base64EncodedString()
      ),
      RunNote(
        label: "fuzzInputByteCount",
        value: String(input.count)
      ),
    ],
    events: ["fuzz-input-failed"],
    targetScore: nil
  )
}
