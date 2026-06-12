// `expectForAll` mirrors `forAll` source-location and example plumbing.
// swiftlint:disable function_parameter_count
#if canImport(Testing)
import PremiseCore

/// Error thrown when an ``expectForAll`` predicate returns `false`.
public struct PropertyPredicateFailed: Error, Sendable, CustomStringConvertible {
  public init() {}

  public var description: String {
    "Predicate returned false"
  }
}

/// Runs a Boolean predicate property through the Swift Testing adapter.
public func expectForAll<Value: Sendable>(
  _ strategy: Strategy<Value>,
  config: PropertyConfig = .default,
  explicitExamples: [Value] = [],
  examples: [ExplicitExample<Value>] = [],
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  function: String = #function,
  _ predicate: @escaping @Sendable (Value) throws -> Bool
) async throws {
  try await forAll(
    strategy,
    config: config,
    explicitExamples: explicitExamples,
    examples: examples,
    fileID: fileID,
    filePath: filePath,
    line: line,
    column: column,
    function: function
  ) { (value: Value) throws -> Void in
    guard try predicate(value) else {
      throw PropertyPredicateFailed()
    }
  }
}

/// Runs an async Boolean predicate property through the Swift Testing adapter.
public func expectForAll<Value: Sendable>(
  _ strategy: Strategy<Value>,
  config: PropertyConfig = .default,
  explicitExamples: [Value] = [],
  examples: [ExplicitExample<Value>] = [],
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  function: String = #function,
  _ predicate: @escaping @Sendable (Value) async throws -> Bool
) async throws {
  try await forAll(
    strategy,
    config: config,
    explicitExamples: explicitExamples,
    examples: examples,
    fileID: fileID,
    filePath: filePath,
    line: line,
    column: column,
    function: function
  ) { (value: Value) async throws -> Void in
    guard try await predicate(value) else {
      throw PropertyPredicateFailed()
    }
  }
}

/// Runs a data-aware Boolean predicate property through the Swift Testing adapter.
public func expectForAll<Value: Sendable>(
  _ strategy: Strategy<Value>,
  config: PropertyConfig = .default,
  explicitExamples: [Value] = [],
  examples: [ExplicitExample<Value>] = [],
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  function: String = #function,
  _ predicate: @escaping @Sendable (Value, inout PremiseData) throws -> Bool
) async throws {
  try await forAll(
    strategy,
    config: config,
    explicitExamples: explicitExamples,
    examples: examples,
    fileID: fileID,
    filePath: filePath,
    line: line,
    column: column,
    function: function
  ) { (value: Value, data: inout PremiseData) throws -> Void in
    guard try predicate(value, &data) else {
      throw PropertyPredicateFailed()
    }
  }
}
#endif
// swiftlint:enable function_parameter_count
