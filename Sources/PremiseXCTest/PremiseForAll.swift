#if canImport(XCTest)
import XCTest

import PremiseCore
import PremiseDatabase

func runXCTestForAll<Value: Sendable>(
  strategy: Strategy<Value>,
  options: XCTestRunOptions<Value>,
  property: @escaping @Sendable (Value) throws -> Void
) async throws {
  let identity = makeIdentity(strategy: strategy, options: options)
  let executor = makeExecutor(
    strategy: strategy,
    options: options,
    identity: identity
  )
  let result = try await executor.executeDetailed(
    explicitExamples: options.explicitExamples,
    examples: options.examples,
    property
  )
  reportFailure(result: result, options: options, identity: identity)
}

func runXCTestForAllAsync<Value: Sendable>(
  strategy: Strategy<Value>,
  options: XCTestRunOptions<Value>,
  property: @escaping @Sendable (Value) async throws -> Void
) async throws {
  let identity = makeIdentity(strategy: strategy, options: options)
  let executor = makeExecutor(
    strategy: strategy,
    options: options,
    identity: identity
  )
  let result = try await executor.executeDetailed(
    explicitExamples: options.explicitExamples,
    examples: options.examples,
    property
  )
  reportFailure(result: result, options: options, identity: identity)
}

private func makeIdentity<Value>(
  strategy: Strategy<Value>,
  options: XCTestRunOptions<Value>
) -> PropertyIdentity {
  PropertyIdentity(
    fileID: options.fileID,
    line: options.line,
    strategyLabel: strategy.label,
    functionName: options.function
  )
}

private func makeExecutor<Value>(
  strategy: Strategy<Value>,
  options: XCTestRunOptions<Value>,
  identity: PropertyIdentity
) -> ReplayFirstExecutor<Value> {
  let runner = Runner(
    strategy: strategy,
    config: options.config,
    propertyID: identity
  )
  return ReplayFirstExecutor(
    runner: runner,
    database: makeDatabase(config: options.config)
  )
}

private func reportFailure<Value>(
  result: DetailedRunResult<Value>,
  options: XCTestRunOptions<Value>,
  identity: PropertyIdentity
) {
  guard case .failure(let record, value: let value, report: let report) = result
  else {
    return
  }
  let context = XCTestFailureContext(
    record: record,
    propertyID: identity,
    report: report,
    includeReproductionBlob: options.config.printReproductionBlob
  )
  XCTFail(
    XCTestFailureFormatter.format(value: value, context: context),
    file: options.file,
    line: options.line
  )
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
