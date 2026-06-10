#if canImport(Testing)
import Testing

import PremiseCore
import PremiseDatabase
import PremiseStrategies

// MARK: - Single-strategy forAll

/// Runs a property test through the Premise engine inside a swift-testing
/// context.
///
/// `forAll` constructs a ``Runner`` from the given strategy and configuration,
/// wraps it in a ``ReplayFirstExecutor`` backed by a ``FileBackedDatabase``,
/// and reports any failure as a swift-testing ``Issue`` containing the
/// minimized counterexample, run/shrink counts, and a replay instruction.
///
/// ```swift
/// @Test func reverseIsInvolution() async throws {
///     try await forAll(.integers(in: 0...100)) { n in
///         #expect(n == n)
///     }
/// }
/// ```
public func forAll<Value: Sendable>(
  _ strategy: Strategy<Value>,
  config: PropertyConfig = .default,
  explicitExamples: [Value] = [],
  examples: [ExplicitExample<Value>] = [],
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  function: String = #function,
  _ property: @escaping @Sendable (Value) throws -> Void
) async throws {
  try await runForAll(
    strategy: strategy,
    config: config,
    explicitExamples: explicitExamples,
    examples: examples,
    fileID: fileID,
    filePath: filePath,
    line: line,
    column: column,
    function: function,
    property: property
  )
}

/// Runs an async property test through the Premise engine inside a
/// swift-testing context.
public func forAll<Value: Sendable>(
  _ strategy: Strategy<Value>,
  config: PropertyConfig = .default,
  explicitExamples: [Value] = [],
  examples: [ExplicitExample<Value>] = [],
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  function: String = #function,
  _ property: @escaping @Sendable (Value) async throws -> Void
) async throws {
  try await runForAllAsync(
    strategy: strategy,
    config: config,
    explicitExamples: explicitExamples,
    examples: examples,
    fileID: fileID,
    filePath: filePath,
    line: line,
    column: column,
    function: function,
    property: property
  )
}

// MARK: - Two-strategy forAll

/// Runs a property test over two independently generated values.
///
/// ```swift
/// @Test func additionIsCommutative() async throws {
///     try await forAll(.integers(in: 0...100), .integers(in: 0...100)) { a, b in
///         #expect(a + b == b + a)
///     }
/// }
/// ```
public func forAll<A: Sendable, B: Sendable>(
  _ strategyA: Strategy<A>,
  _ strategyB: Strategy<B>,
  config: PropertyConfig = .default,
  explicitExamples: [(A, B)] = [],
  examples: [ExplicitExample<(A, B)>] = [],
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  function: String = #function,
  _ property: @escaping @Sendable (A, B) throws -> Void
) async throws {
  let combined = Strategy<(A, B)>(
    label: "(\(strategyA.label), \(strategyB.label))",
    draw: { data in
      let a = try strategyA.draw(&data)
      let b = try strategyB.draw(&data)
      return (a, b)
    },
    shrink: { pair in
      let shrunkA = strategyA.shrink(pair.0).map { ($0, pair.1) }
      let shrunkB = strategyB.shrink(pair.1).map { (pair.0, $0) }
      return shrunkA + shrunkB
    }
  )
  try await runForAll(
    strategy: combined,
    config: config,
    explicitExamples: explicitExamples,
    examples: examples,
    fileID: fileID,
    filePath: filePath,
    line: line,
    column: column,
    function: function
  ) { pair in
    try property(pair.0, pair.1)
  }
}

/// Runs an async property test over two independently generated values.
public func forAll<A: Sendable, B: Sendable>(
  _ strategyA: Strategy<A>,
  _ strategyB: Strategy<B>,
  config: PropertyConfig = .default,
  explicitExamples: [(A, B)] = [],
  examples: [ExplicitExample<(A, B)>] = [],
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  function: String = #function,
  _ property: @escaping @Sendable (A, B) async throws -> Void
) async throws {
  let combined = zip(strategyA, strategyB)
  try await runForAllAsync(
    strategy: combined,
    config: config,
    explicitExamples: explicitExamples,
    examples: examples,
    fileID: fileID,
    filePath: filePath,
    line: line,
    column: column,
    function: function
  ) { pair in
    try await property(pair.0, pair.1)
  }
}

// MARK: - Three-strategy forAll

/// Runs a property test over three independently generated values.
///
/// ```swift
/// @Test func additionIsAssociative() async throws {
///     try await forAll(
///         .integers(in: 0...100),
///         .integers(in: 0...100),
///         .integers(in: 0...100)
///     ) { a, b, c in
///         #expect((a + b) + c == a + (b + c))
///     }
/// }
/// ```
public func forAll<A: Sendable, B: Sendable, C: Sendable>(
  _ strategyA: Strategy<A>,
  _ strategyB: Strategy<B>,
  _ strategyC: Strategy<C>,
  config: PropertyConfig = .default,
  explicitExamples: [(A, B, C)] = [],
  examples: [ExplicitExample<(A, B, C)>] = [],
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  function: String = #function,
  _ property: @escaping @Sendable (A, B, C) throws -> Void
) async throws {
  let combined = Strategy<(A, B, C)>(
    label: "(\(strategyA.label), \(strategyB.label), \(strategyC.label))",
    draw: { data in
      let a = try strategyA.draw(&data)
      let b = try strategyB.draw(&data)
      let c = try strategyC.draw(&data)
      return (a, b, c)
    },
    shrink: { triple in
      let sA = strategyA.shrink(triple.0).map { ($0, triple.1, triple.2) }
      let sB = strategyB.shrink(triple.1).map { (triple.0, $0, triple.2) }
      let sC = strategyC.shrink(triple.2).map { (triple.0, triple.1, $0) }
      return sA + sB + sC
    }
  )
  try await runForAll(
    strategy: combined,
    config: config,
    explicitExamples: explicitExamples,
    examples: examples,
    fileID: fileID,
    filePath: filePath,
    line: line,
    column: column,
    function: function
  ) { triple in
    try property(triple.0, triple.1, triple.2)
  }
}

/// Runs an async property test over three independently generated values.
public func forAll<A: Sendable, B: Sendable, C: Sendable>(
  _ strategyA: Strategy<A>,
  _ strategyB: Strategy<B>,
  _ strategyC: Strategy<C>,
  config: PropertyConfig = .default,
  explicitExamples: [(A, B, C)] = [],
  examples: [ExplicitExample<(A, B, C)>] = [],
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  function: String = #function,
  _ property: @escaping @Sendable (A, B, C) async throws -> Void
) async throws {
  let combined = zip(strategyA, strategyB, strategyC)
  try await runForAllAsync(
    strategy: combined,
    config: config,
    explicitExamples: explicitExamples,
    examples: examples,
    fileID: fileID,
    filePath: filePath,
    line: line,
    column: column,
    function: function
  ) { triple in
    try await property(triple.0, triple.1, triple.2)
  }
}

// MARK: - forAll with PremiseData access

/// Runs a property test that also receives a ``PremiseData`` reference
/// for recording notes, events, and target scores.
///
/// ```swift
/// @Test func sortedArrayIsSorted() async throws {
///     try await forAll(.arrays(of: .integers(in: 0...100), length: 0...20)) { array, data in
///         data.note("length", value: array.count)
///         data.event(array.isEmpty ? "empty" : "non-empty")
///         let sorted = array.sorted()
///         #expect(zip(sorted, sorted.dropFirst()).allSatisfy { $0 <= $1 })
///     }
/// }
/// ```
public func forAll<Value: Sendable>(
  _ strategy: Strategy<Value>,
  config: PropertyConfig = .default,
  explicitExamples: [Value] = [],
  examples: [ExplicitExample<Value>] = [],
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  function: String = #function,
  _ property: @escaping @Sendable (Value, inout PremiseData) throws -> Void
) async throws {
  let propertyID = PropertyIdentity(
    fileID: fileID,
    line: UInt(line),
    strategyLabel: strategy.label,
    functionName: function
  )

  let runner = Runner(
    strategy: strategy,
    config: config,
    propertyID: propertyID
  )
  let database = makeDatabase(config: config)
  let executor = ReplayFirstExecutor(runner: runner, database: database)
  let result = try await executor.executeDetailed(
    explicitExamples: explicitExamples,
    examples: examples,
    property
  )

  if case .failure(let record, value: let value, report: let report) = result {
    let message = FailureFormatter.format(
      value: value,
      record: record,
      propertyID: propertyID,
      report: report
    )
    let sourceLocation = SourceLocation(
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
    Issue.record(
      Comment(rawValue: message),
      sourceLocation: sourceLocation
    )
  }
}

// MARK: - Internal

/// Shared implementation for all forAll variants.
// swiftlint:disable:next function_parameter_count
private func runForAll<Value: Sendable>(
  strategy: Strategy<Value>,
  config: PropertyConfig,
  explicitExamples: [Value] = [],
  examples: [ExplicitExample<Value>] = [],
  fileID: String,
  filePath: String,
  line: Int,
  column: Int,
  function: String,
  property: @escaping @Sendable (Value) throws -> Void
) async throws {
  let propertyID = PropertyIdentity(
    fileID: fileID,
    line: UInt(line),
    strategyLabel: strategy.label,
    functionName: function
  )

  let runner = Runner(
    strategy: strategy,
    config: config,
    propertyID: propertyID
  )

  let database = makeDatabase(config: config)
  let executor = ReplayFirstExecutor(runner: runner, database: database)
  let result = try await executor.executeDetailed(
    explicitExamples: explicitExamples,
    examples: examples,
    property
  )

  if case .failure(let record, value: let value, report: let report) = result {
    let message = FailureFormatter.format(
      value: value,
      record: record,
      propertyID: propertyID,
      report: report
    )
    let sourceLocation = SourceLocation(
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
    Issue.record(
      Comment(rawValue: message),
      sourceLocation: sourceLocation
    )
  }
}

// swiftlint:disable:next function_parameter_count
private func runForAllAsync<Value: Sendable>(
  strategy: Strategy<Value>,
  config: PropertyConfig,
  explicitExamples: [Value] = [],
  examples: [ExplicitExample<Value>] = [],
  fileID: String,
  filePath: String,
  line: Int,
  column: Int,
  function: String,
  property: @escaping @Sendable (Value) async throws -> Void
) async throws {
  let propertyID = PropertyIdentity(
    fileID: fileID,
    line: UInt(line),
    strategyLabel: strategy.label,
    functionName: function
  )

  let runner = Runner(
    strategy: strategy,
    config: config,
    propertyID: propertyID
  )

  let database = makeDatabase(config: config)
  let executor = ReplayFirstExecutor(runner: runner, database: database)
  let result = try await executor.executeDetailed(
    explicitExamples: explicitExamples,
    examples: examples,
    property
  )

  if case .failure(let record, value: let value, report: let report) = result {
    let message = FailureFormatter.format(
      value: value,
      record: record,
      propertyID: propertyID,
      report: report
    )
    let sourceLocation = SourceLocation(
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
    Issue.record(
      Comment(rawValue: message),
      sourceLocation: sourceLocation
    )
  }
}

private func makeDatabase(config: PropertyConfig) -> any ExampleDatabase {
  let local = FileBackedDatabase(rootDirectory: config.localDatabaseDirectory)
  guard let corpusDirectory = config.committedCorpusDirectory else {
    return local
  }
  let corpus = FileBackedDatabase(rootDirectory: corpusDirectory)
  return CompositeExampleDatabase(
    replaySources: [corpus, local],
    writableDatabase: local
  )
}
#endif
