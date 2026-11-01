// Pattern helpers mirror `forAll` source-location and example plumbing.
#if canImport(Testing)
import PremiseCore

/// Checks that encoding then decoding preserves values from `strategy`.
public func expectRoundTrip<Value: Sendable, Encoded: Sendable>(
  // swiftlint:disable:previous function_parameter_count
  // Preserve round-trip closures, examples, and caller-captured source locations.
  _ strategy: Strategy<Value>,
  config: PropertyConfig = .default,
  explicitExamples: [Value] = [],
  examples: [ExplicitExample<Value>] = [],
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  function: String = #function,
  encode: @escaping @Sendable (Value) throws -> Encoded,
  decode: @escaping @Sendable (Encoded) throws -> Value,
  equivalent: @escaping @Sendable (Value, Value) throws -> Bool
) async throws {
  try await expectForAll(
    strategy,
    config: config,
    explicitExamples: explicitExamples,
    examples: examples,
    fileID: fileID,
    filePath: filePath,
    line: line,
    column: column,
    function: function
  ) { value in
    let encoded = try encode(value)
    let decoded = try decode(encoded)
    return try equivalent(value, decoded)
  }
}

/// Checks that a pure model and async implementation agree for generated inputs.
public func expectModelAgreement<
  // swiftlint:disable:previous function_parameter_count
  // Preserve model and implementation closures, examples, and caller-captured source locations.
  Input: Sendable,
  Model: Sendable,
  Actual: Sendable
>(
  _ strategy: Strategy<Input>,
  config: PropertyConfig = .default,
  explicitExamples: [Input] = [],
  examples: [ExplicitExample<Input>] = [],
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  function: String = #function,
  model: @escaping @Sendable (Input) throws -> Model,
  actual: @escaping @Sendable (Input) async throws -> Actual,
  equivalent: @escaping @Sendable (Model, Actual) throws -> Bool
) async throws {
  try await expectForAll(
    strategy,
    config: config,
    explicitExamples: explicitExamples,
    examples: examples,
    fileID: fileID,
    filePath: filePath,
    line: line,
    column: column,
    function: function
  ) { input in
    let expected = try model(input)
    let observed = try await actual(input)
    return try equivalent(expected, observed)
  }
}
#endif
