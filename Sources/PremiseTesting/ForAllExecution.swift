#if canImport(Testing)
import Testing
import PremiseCore
import PremiseDatabase

// swiftlint:disable function_parameter_count - Strategy, configuration, examples, source coordinates, and property originate independently.
/// Shared implementation for all forAll variants.
func runForAll<Value: Sendable>(
  strategy: Strategy<Value>,
  config: PropertyConfig,
  explicitExamples: [Value],
  examples: [ExplicitExample<Value>],
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

  let executor = makeExecutor(strategy, config: config, propertyID: propertyID)
  let result = try await executor.executeDetailed(
    explicitExamples: explicitExamples,
    examples: examples,
    property
  )

  reportForAllResult(
    result,
    propertyID: propertyID,
    config: config,
    location: makeLocation(fileID, filePath, line, column)
  )
}
// swiftlint:enable function_parameter_count

// swiftlint:disable:next function_parameter_count - Async execution preserves independent examples, source coordinates, strategy, and property.
func runForAllAsync<Value: Sendable>(
  strategy: Strategy<Value>,
  config: PropertyConfig,
  explicitExamples: [Value],
  examples: [ExplicitExample<Value>],
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

  let executor = makeExecutor(strategy, config: config, propertyID: propertyID)
  let result = try await executor.executeDetailed(
    explicitExamples: explicitExamples,
    examples: examples,
    property
  )

  reportForAllResult(
    result,
    propertyID: propertyID,
    config: config,
    location: makeLocation(fileID, filePath, line, column)
  )
}

func makeExecutor<Value: Sendable>(
  _ strategy: Strategy<Value>,
  config: PropertyConfig,
  propertyID: PropertyIdentity
) -> ReplayFirstExecutor<Value> {
  let runner = Runner(
    strategy: strategy,
    config: config,
    propertyID: propertyID
  )
  return ReplayFirstExecutor(
    runner: runner,
    database: makeDatabase(config: config)
  )
}

// swiftlint:disable:next function_parameter_count - Result, identity, configuration, and reporting location have distinct roles.
func reportForAllResult<Value: Sendable>(
  _ result: DetailedRunResult<Value>,
  propertyID: PropertyIdentity,
  config: PropertyConfig,
  location: SourceLocation
) {
  guard
    case .failure(
      let record,
      value: let value,
      report: let report
    ) = result
  else {
    return
  }
  let message = FailureFormatter.format(
    value: value,
    record: record,
    propertyID: propertyID,
    report: report,
    includeReproductionBlob: config.printReproductionBlob
  )
  Issue.record(Comment(rawValue: message), sourceLocation: location)
}

// swiftlint:disable:next function_parameter_count - SourceLocation requires the independent file ID, path, line, and column.
func makeLocation(
  _ fileID: String,
  _ filePath: String,
  _ line: Int,
  _ column: Int
) -> SourceLocation {
  SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
}
func makeDatabase(config: PropertyConfig) -> any ExampleDatabase {
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
