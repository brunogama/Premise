import Foundation
import PremiseCore

/// Runs a single byte input from an external fuzzer through a Premise strategy.
///
/// Draw-phase strategy errors and explicit property rejections are treated as
/// invalid fuzz inputs and returned as ``FuzzOutcome/rejected``. If the input
/// runs out while drawing, the property body is skipped and the result is
/// ``FuzzOutcome/exhausted``. Property failures are persisted according to
/// ``FuzzConfig`` and rethrown as ``FuzzFailure``.
@discardableResult
public func fuzzOneInput<Value: Sendable>(
  // swiftlint:disable:previous function_parameter_count
  // Keep the async overload's four arguments for source and binary compatibility.
  _ input: Data,
  strategy: Strategy<Value>,
  config: FuzzConfig = FuzzConfig(),
  _ property: @escaping @Sendable (Value) async throws -> Void
) async throws -> FuzzRunResult {
  try await runFuzzOneInput(
    request: FuzzRunRequest(input: input, config: config),
    strategy: strategy,
    property: property
  )
}

/// Synchronous-property overload of ``fuzzOneInput(_:strategy:config:_:)``.
@discardableResult
public func fuzzOneInput<Value: Sendable>(
  // swiftlint:disable:previous function_parameter_count
  // Keep the synchronous overload's four arguments for source and binary compatibility.
  _ input: Data,
  strategy: Strategy<Value>,
  config: FuzzConfig = FuzzConfig(),
  _ property: @escaping @Sendable (Value) throws -> Void
) async throws -> FuzzRunResult {
  try await runFuzzOneInput(
    request: FuzzRunRequest(input: input, config: config),
    strategy: strategy
  ) { value in
    try property(value)
  }
}

/// Byte-array overload for fuzzer integrations that do not use `Data`.
@discardableResult
public func fuzzOneInput<Value: Sendable>(
  // swiftlint:disable:previous function_parameter_count
  // Keep the byte-array overload's four arguments for source and binary compatibility.
  bytes: [UInt8],
  strategy: Strategy<Value>,
  config: FuzzConfig = FuzzConfig(),
  _ property: @escaping @Sendable (Value) async throws -> Void
) async throws -> FuzzRunResult {
  try await runFuzzOneInput(
    request: FuzzRunRequest(input: Data(bytes), config: config),
    strategy: strategy,
    property: property
  )
}
