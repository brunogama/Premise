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
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  function: String = #function,
  _ property: @escaping @Sendable (Value) throws -> Void
) async throws {
  try await _runForAll(
    strategy: strategy,
    config: config,
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
  try await _runForAll(
    strategy: combined,
    config: config,
    fileID: fileID,
    filePath: filePath,
    line: line,
    column: column,
    function: function
  ) { pair in
    try property(pair.0, pair.1)
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
  try await _runForAll(
    strategy: combined,
    config: config,
    fileID: fileID,
    filePath: filePath,
    line: line,
    column: column,
    function: function
  ) { triple in
    try property(triple.0, triple.1, triple.2)
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
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  function: String = #function,
  _ property: @escaping @Sendable (Value, inout PremiseData) throws -> Void
) async throws {
  // Wrap the data-aware property into a strategy that captures the data
  // reference through the draw phase.
  let wrappedStrategy = Strategy<Value>(
    label: strategy.label,
    draw: strategy.draw,
    shrink: strategy.shrink
  )
  let propertyID = PropertyIdentity(
    fileID: fileID,
    line: UInt(line),
    strategyLabel: strategy.label,
    functionName: function
  )

  let runner = Runner(
    strategy: wrappedStrategy,
    config: config,
    propertyID: propertyID
  )

  // For the data-aware variant we run manually so we can pass data through.
  let baseSeed = config.seed ?? UInt64.random(in: .min ... .max)

  for index in 0..<config.maxRuns {
    let providerSeed = baseSeed &+ UInt64(index)
    let provider = PseudoRandomProvider(seed: providerSeed, maxDraws: config.maxDrawsPerRun)
    var data = PremiseData(provider: provider)

    let drawnValue: Value
    do {
      drawnValue = try strategy.draw(&data)
    } catch {
      continue  // Strategy couldn't produce a valid input, skip.
    }

    do {
      try property(drawnValue, &data)
    } catch {
      let minimized = runner.minimizeTrace(
        initialTrace: data.snapshot(),
        errorMessage: String(describing: error),
        initialValue: drawnValue,
        runCount: index + 1,
        property: { value in try property(value, &data) },
        seed: baseSeed
      )
      let message = FailureFormatter.format(
        value: minimized.value,
        record: minimized.record,
        propertyID: propertyID
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
      return
    }
  }
}

// MARK: - Internal

/// Shared implementation for all forAll variants.
// swiftlint:disable:next function_parameter_count
private func _runForAll<Value: Sendable>(
  strategy: Strategy<Value>,
  config: PropertyConfig,
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

  let database = FileBackedDatabase()
  let executor = ReplayFirstExecutor(runner: runner, database: database)
  let result = try await executor.execute(property)

  if case .failure(let record, value: let value) = result {
    let message = FailureFormatter.format(
      value: value,
      record: record,
      propertyID: propertyID
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
#endif
