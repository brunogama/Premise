#if canImport(XCTest)
import XCTest

import PremiseCore
import PremiseDatabase
import PremiseStrategies

// MARK: - Single-strategy premise_forAll

// swift-format-ignore: AlwaysUseLowerCamelCase
/// Runs a property test through the Premise engine inside an XCTest
/// context.
///
/// `premise_forAll` constructs a ``Runner`` from the given strategy and
/// configuration, wraps it in a ``ReplayFirstExecutor`` backed by a
/// ``FileBackedDatabase``, and reports any failure through `XCTFail` at the
/// caller's source location with the minimized counterexample, run/shrink
/// counts, and a replay instruction.
public func premise_forAll<Value: Sendable>(
  _ strategy: Strategy<Value>,
  config: PropertyConfig = .default,
  fileID: String = #fileID,
  file: StaticString = #filePath,
  line: UInt = #line,
  function: String = #function,
  _ property: @escaping @Sendable (Value) throws -> Void
) async throws {
  try await runXCTestForAll(
    strategy: strategy,
    config: config,
    fileID: fileID,
    file: file,
    line: line,
    function: function,
    property: property
  )
}

// swift-format-ignore: AlwaysUseLowerCamelCase
/// Runs an async property test through the Premise engine inside XCTest.
public func premise_forAll<Value: Sendable>(
  _ strategy: Strategy<Value>,
  config: PropertyConfig = .default,
  fileID: String = #fileID,
  file: StaticString = #filePath,
  line: UInt = #line,
  function: String = #function,
  _ property: @escaping @Sendable (Value) async throws -> Void
) async throws {
  try await runXCTestForAllAsync(
    strategy: strategy,
    config: config,
    fileID: fileID,
    file: file,
    line: line,
    function: function,
    property: property
  )
}

// MARK: - Two-strategy premise_forAll

// swift-format-ignore: AlwaysUseLowerCamelCase
/// Runs a property test over two independently generated values in XCTest.
public func premise_forAll<A: Sendable, B: Sendable>(
  _ strategyA: Strategy<A>,
  _ strategyB: Strategy<B>,
  config: PropertyConfig = .default,
  fileID: String = #fileID,
  file: StaticString = #filePath,
  line: UInt = #line,
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
  try await runXCTestForAll(
    strategy: combined,
    config: config,
    fileID: fileID,
    file: file,
    line: line,
    function: function
  ) { pair in
    try property(pair.0, pair.1)
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
/// Runs an async property test over two independently generated values in XCTest.
public func premise_forAll<A: Sendable, B: Sendable>(
  _ strategyA: Strategy<A>,
  _ strategyB: Strategy<B>,
  config: PropertyConfig = .default,
  fileID: String = #fileID,
  file: StaticString = #filePath,
  line: UInt = #line,
  function: String = #function,
  _ property: @escaping @Sendable (A, B) async throws -> Void
) async throws {
  let combined = zip(strategyA, strategyB)
  try await runXCTestForAllAsync(
    strategy: combined,
    config: config,
    fileID: fileID,
    file: file,
    line: line,
    function: function
  ) { pair in
    try await property(pair.0, pair.1)
  }
}

// MARK: - Three-strategy premise_forAll

// swift-format-ignore: AlwaysUseLowerCamelCase
/// Runs a property test over three independently generated values in XCTest.
public func premise_forAll<A: Sendable, B: Sendable, C: Sendable>(
  _ strategyA: Strategy<A>,
  _ strategyB: Strategy<B>,
  _ strategyC: Strategy<C>,
  config: PropertyConfig = .default,
  fileID: String = #fileID,
  file: StaticString = #filePath,
  line: UInt = #line,
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
  try await runXCTestForAll(
    strategy: combined,
    config: config,
    fileID: fileID,
    file: file,
    line: line,
    function: function
  ) { triple in
    try property(triple.0, triple.1, triple.2)
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
/// Runs an async property test over three independently generated values in XCTest.
public func premise_forAll<A: Sendable, B: Sendable, C: Sendable>(
  _ strategyA: Strategy<A>,
  _ strategyB: Strategy<B>,
  _ strategyC: Strategy<C>,
  config: PropertyConfig = .default,
  fileID: String = #fileID,
  file: StaticString = #filePath,
  line: UInt = #line,
  function: String = #function,
  _ property: @escaping @Sendable (A, B, C) async throws -> Void
) async throws {
  let combined = zip(strategyA, strategyB, strategyC)
  try await runXCTestForAllAsync(
    strategy: combined,
    config: config,
    fileID: fileID,
    file: file,
    line: line,
    function: function
  ) { triple in
    try await property(triple.0, triple.1, triple.2)
  }
}

// MARK: - Internal

// swiftlint:disable:next function_parameter_count
private func runXCTestForAll<Value: Sendable>(
  strategy: Strategy<Value>,
  config: PropertyConfig,
  fileID: String,
  file: StaticString,
  line: UInt,
  function: String,
  property: @escaping @Sendable (Value) throws -> Void
) async throws {
  let propertyID = PropertyIdentity(
    fileID: fileID,
    line: line,
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
  let result = try await executor.executeDetailed(property)

  if case .failure(let record, value: let value, report: let report) = result {
    let message = XCTestFailureFormatter.format(
      value: value,
      record: record,
      propertyID: propertyID,
      report: report
    )
    XCTFail(message, file: file, line: line)
  }
}

// swiftlint:disable:next function_parameter_count
private func runXCTestForAllAsync<Value: Sendable>(
  strategy: Strategy<Value>,
  config: PropertyConfig,
  fileID: String,
  file: StaticString,
  line: UInt,
  function: String,
  property: @escaping @Sendable (Value) async throws -> Void
) async throws {
  let propertyID = PropertyIdentity(
    fileID: fileID,
    line: line,
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
  let result = try await executor.executeDetailed(property)

  if case .failure(let record, value: let value, report: let report) = result {
    let message = XCTestFailureFormatter.format(
      value: value,
      record: record,
      propertyID: propertyID,
      report: report
    )
    XCTFail(message, file: file, line: line)
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
