import PremiseCore
import PremiseDatabase
import Foundation
import Testing

private enum ExportFailure: Error {
  case boom
}

@Suite("Failure trace export and replay corpus")
struct FailureTraceExportTests {
  private func makeTempDirectory() throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: tempDir,
      withIntermediateDirectories: true
    )
    return tempDir
  }

  private func makePropertyID() -> PropertyIdentity {
    PropertyIdentity(
      fileID: "FailureTraceExportTests",
      line: 1,
      strategyLabel: "exportInt",
      functionName: "failingProperty"
    )
  }

  @Test("ReplayFirstExecutor writes JSON failure trace artifacts")
  func executorWritesJSONFailureTraceArtifacts() async throws {
    let tempDir = try makeTempDirectory()
    let localDir = tempDir.appendingPathComponent("local", isDirectory: true)
    let exportDir = tempDir.appendingPathComponent("artifacts", isDirectory: true)
    let propertyID = makePropertyID()
    let strategy = Strategy<Int>.just(1)
    let config = PropertyConfig(
      maxRuns: 1,
      seed: 42,
      traceExportDirectory: exportDir
    )
    let runner = Runner(strategy: strategy, config: config, propertyID: propertyID)
    let database = FileBackedDatabase(rootDirectory: localDir)
    let executor = ReplayFirstExecutor(runner: runner, database: database)

    let result = try await executor.execute { value in
      if value == 1 {
        throw ExportFailure.boom
      }
    }

    guard case .failure = result else {
      Issue.record("Expected failure to be exported")
      return
    }

    let files = try FileManager.default.contentsOfDirectory(
      at: exportDir,
      includingPropertiesForKeys: nil
    )
    #expect(files.count == 1)

    let data = try Data(contentsOf: files[0])
    let artifact = try JSONDecoder().decode(FailureTraceArtifact.self, from: data)
    #expect(artifact.record.propertyID == propertyID)
    #expect(artifact.record.seed == 42)
    #expect(artifact.record.discovery == .newFailure)
  }

  @Test("Composite database replays committed corpus before local traces")
  func compositeDatabaseReplaysCommittedCorpusBeforeLocalTraces() async throws {
    let tempDir = try makeTempDirectory()
    let corpus = FileBackedDatabase(
      rootDirectory: tempDir.appendingPathComponent("corpus", isDirectory: true)
    )
    let local = FileBackedDatabase(
      rootDirectory: tempDir.appendingPathComponent("local", isDirectory: true)
    )
    let database = CompositeExampleDatabase(
      replaySources: [corpus, local],
      writableDatabase: local
    )
    let propertyID = makePropertyID()

    try await corpus.save(
      FailureRecord(
        propertyID: propertyID,
        trace: ChoiceTrace(entries: [.integer(1)]),
        errorMessage: "corpus"
      )
    )
    try await local.save(
      FailureRecord(
        propertyID: propertyID,
        trace: ChoiceTrace(entries: [.integer(2)]),
        errorMessage: "local"
      )
    )

    let traces = try await database.loadTraces(for: propertyID)
    #expect(traces.map(\.entries) == [[.integer(1)], [.integer(2)]])

    try await database.save(
      FailureRecord(
        propertyID: propertyID,
        trace: ChoiceTrace(entries: [.integer(3)]),
        errorMessage: "new"
      )
    )

    let corpusTraces = try await corpus.loadTraces(for: propertyID)
    let localTraces = try await local.loadTraces(for: propertyID)
    #expect(corpusTraces.map(\.entries) == [[.integer(1)]])
    #expect(localTraces.map(\.entries) == [[.integer(2)], [.integer(3)]])
  }
}
