#if canImport(Testing)
import PremiseCore
import PremiseStrategies

/// Runs a property over independently generated values.
@_disfavoredOverload
public func forAll<each Value: Sendable>(
  // swiftlint:disable:previous function_parameter_count
  // Preserve the synchronous variadic API and caller-captured source locations.
  _ strategies: repeat Strategy<each Value>,
  config: PropertyConfig = .default,
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  function: String = #function,
  _ property: @escaping @Sendable (repeat each Value) throws -> Void
) async throws {
  let combined = zip(repeat each strategies)
  try await forAll(
    combined,
    config: config,
    fileID: fileID,
    filePath: filePath,
    line: line,
    column: column,
    function: function
  ) { values in
    try property(repeat each values)
  }
}

/// Runs an asynchronous property over independently generated values.
@_disfavoredOverload
public func forAll<each Value: Sendable>(
  // swiftlint:disable:previous function_parameter_count
  // Preserve the async variadic API and caller-captured source locations.
  _ strategies: repeat Strategy<each Value>,
  config: PropertyConfig = .default,
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  function: String = #function,
  _ property: @escaping @Sendable (repeat each Value) async throws -> Void
) async throws {
  let combined = zip(repeat each strategies)
  try await forAll(
    combined,
    config: config,
    fileID: fileID,
    filePath: filePath,
    line: line,
    column: column,
    function: function
  ) { values in
    try await property(repeat each values)
  }
}
#endif
