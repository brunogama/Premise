#if canImport(XCTest)
import PremiseCore
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
  // swiftlint:disable:previous function_parameter_count
  // Preserve public arguments and caller-captured source locations.
  _ strategy: Strategy<Value>,
  config: PropertyConfig = .default,
  explicitExamples: [Value] = [],
  examples: [ExplicitExample<Value>] = [],
  fileID: String = #fileID,
  file: StaticString = #filePath,
  line: UInt = #line,
  function: String = #function,
  _ property: @escaping @Sendable (Value) throws -> Void
) async throws {
  try await runXCTestForAll(
    strategy: strategy,
    options: XCTestRunOptions(
      config: config,
      explicitExamples: explicitExamples,
      examples: examples,
      fileID: fileID,
      file: file,
      line: line,
      function: function
    ),
    property: property
  )
}

// swift-format-ignore: AlwaysUseLowerCamelCase
/// Runs an async property test through the Premise engine inside XCTest.
public func premise_forAll<Value: Sendable>(
  // swiftlint:disable:previous function_parameter_count
  // Preserve public arguments and caller-captured source locations.
  _ strategy: Strategy<Value>,
  config: PropertyConfig = .default,
  explicitExamples: [Value] = [],
  examples: [ExplicitExample<Value>] = [],
  fileID: String = #fileID,
  file: StaticString = #filePath,
  line: UInt = #line,
  function: String = #function,
  _ property: @escaping @Sendable (Value) async throws -> Void
) async throws {
  try await runXCTestForAllAsync(
    strategy: strategy,
    options: XCTestRunOptions(
      config: config,
      explicitExamples: explicitExamples,
      examples: examples,
      fileID: fileID,
      file: file,
      line: line,
      function: function
    ),
    property: property
  )
}

// MARK: - Two-strategy premise_forAll

// swift-format-ignore: AlwaysUseLowerCamelCase
/// Runs a property test over two independently generated values in XCTest.
public func premise_forAll<A: Sendable, B: Sendable>(
  // swiftlint:disable:previous function_parameter_count
  // Preserve public arguments and caller-captured source locations.
  _ strategyA: Strategy<A>,
  _ strategyB: Strategy<B>,
  config: PropertyConfig = .default,
  explicitExamples: [(A, B)] = [],
  examples: [ExplicitExample<(A, B)>] = [],
  fileID: String = #fileID,
  file: StaticString = #filePath,
  line: UInt = #line,
  function: String = #function,
  _ property: @escaping @Sendable (A, B) throws -> Void
) async throws {
  let combined = syncPairStrategy(strategyA, strategyB)
  try await runXCTestForAll(
    strategy: combined,
    options: XCTestRunOptions(
      config: config,
      explicitExamples: explicitExamples,
      examples: examples,
      fileID: fileID,
      file: file,
      line: line,
      function: function
    )
  ) { pair in
    try property(pair.0, pair.1)
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
/// Runs an async property test over two independently generated values in XCTest.
public func premise_forAll<A: Sendable, B: Sendable>(
  // swiftlint:disable:previous function_parameter_count
  // Preserve public arguments and caller-captured source locations.
  _ strategyA: Strategy<A>,
  _ strategyB: Strategy<B>,
  config: PropertyConfig = .default,
  explicitExamples: [(A, B)] = [],
  examples: [ExplicitExample<(A, B)>] = [],
  fileID: String = #fileID,
  file: StaticString = #filePath,
  line: UInt = #line,
  function: String = #function,
  _ property: @escaping @Sendable (A, B) async throws -> Void
) async throws {
  let combined = zip(strategyA, strategyB)
  try await runXCTestForAllAsync(
    strategy: combined,
    options: XCTestRunOptions(
      config: config,
      explicitExamples: explicitExamples,
      examples: examples,
      fileID: fileID,
      file: file,
      line: line,
      function: function
    )
  ) { pair in
    try await property(pair.0, pair.1)
  }
}

// MARK: - Three-strategy premise_forAll

// swift-format-ignore: AlwaysUseLowerCamelCase
/// Runs a property test over three independently generated values in XCTest.
public func premise_forAll<A: Sendable, B: Sendable, C: Sendable>(
  // swiftlint:disable:previous function_parameter_count
  // Preserve public arguments and caller-captured source locations.
  _ strategyA: Strategy<A>,
  _ strategyB: Strategy<B>,
  _ strategyC: Strategy<C>,
  config: PropertyConfig = .default,
  // Existing callers supply three-element tuples.
  // swiftlint:disable:next large_tuple
  explicitExamples: [(A, B, C)] = [],
  // Existing callers supply three-element tuples.
  // swiftlint:disable:next large_tuple
  examples: [ExplicitExample<(A, B, C)>] = [],
  fileID: String = #fileID,
  file: StaticString = #filePath,
  line: UInt = #line,
  function: String = #function,
  _ property: @escaping @Sendable (A, B, C) throws -> Void
) async throws {
  let zipped = zip(strategyA, strategyB, strategyC)
  let combined = Strategy(
    label: "(\(strategyA.label), \(strategyB.label), \(strategyC.label))",
    draw: zipped.draw,
    shrink: zipped.shrink
  )
  try await runXCTestForAll(
    strategy: combined,
    options: XCTestRunOptions(
      config: config,
      explicitExamples: explicitExamples,
      examples: examples,
      fileID: fileID,
      file: file,
      line: line,
      function: function
    )
  ) { triple in
    try property(triple.0, triple.1, triple.2)
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
/// Runs an async property test over three independently generated values in XCTest.
public func premise_forAll<A: Sendable, B: Sendable, C: Sendable>(
  // swiftlint:disable:previous function_parameter_count
  // Preserve public arguments and caller-captured source locations.
  _ strategyA: Strategy<A>,
  _ strategyB: Strategy<B>,
  _ strategyC: Strategy<C>,
  config: PropertyConfig = .default,
  // Existing callers supply three-element tuples.
  // swiftlint:disable:next large_tuple
  explicitExamples: [(A, B, C)] = [],
  // Existing callers supply three-element tuples.
  // swiftlint:disable:next large_tuple
  examples: [ExplicitExample<(A, B, C)>] = [],
  fileID: String = #fileID,
  file: StaticString = #filePath,
  line: UInt = #line,
  function: String = #function,
  _ property: @escaping @Sendable (A, B, C) async throws -> Void
) async throws {
  let combined = zip(strategyA, strategyB, strategyC)
  try await runXCTestForAllAsync(
    strategy: combined,
    options: XCTestRunOptions(
      config: config,
      explicitExamples: explicitExamples,
      examples: examples,
      fileID: fileID,
      file: file,
      line: line,
      function: function
    )
  ) { triple in
    try await property(triple.0, triple.1, triple.2)
  }
}

private func syncPairStrategy<A: Sendable, B: Sendable>(
  _ first: Strategy<A>,
  _ second: Strategy<B>
) -> Strategy<(A, B)> {
  Strategy(
    label: "(\(first.label), \(second.label))",
    draw: { data in (try first.draw(&data), try second.draw(&data)) },
    shrink: { pair in
      first.shrink(pair.0).map { ($0, pair.1) }
        + second.shrink(pair.1).map { (pair.0, $0) }
    }
  )
}

#endif
