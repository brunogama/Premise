import PremiseCore
import PremiseDatabase
import Foundation
import Testing

/// Tests for ``FileBackedDatabase`` file-backed persistence lifecycle.
///
/// Each test uses a unique temporary directory to isolate side effects.
@Suite("FileBackedDatabase persistence lifecycle")
struct FileBackedDatabasePersistenceTests {

  // MARK: - Helpers

  /// Creates a temporary directory and returns its URL.
  private func makeTempDirectory() throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: tempDir,
      withIntermediateDirectories: true
    )
    return tempDir
  }

  /// Builds a ``PropertyIdentity`` for testing.
  private func makePropertyID(
    fileID: String = "TestFile.swift",
    line: UInt = 42,
    strategyLabel: String = "Int"
  ) -> PropertyIdentity {
    PropertyIdentity(
      fileID: fileID,
      line: line,
      strategyLabel: strategyLabel
    )
  }

  /// Builds a ``FailureRecord`` with a given property identity and trace.
  private func makeRecord(
    propertyID: PropertyIdentity,
    entries: [ChoiceTrace.Entry] = [.integer(7)]
  ) -> FailureRecord {
    FailureRecord(
      propertyID: propertyID,
      trace: ChoiceTrace(entries: entries),
      errorMessage: "test failure"
    )
  }

  // MARK: - Tests

  @Test("Saving two records returns two traces in insertion order")
  func saveAndLoadMultipleRecords() async throws {
    let tempDir = try makeTempDirectory()
    let db = FileBackedDatabase(rootDirectory: tempDir)
    let id = makePropertyID()

    let record1 = makeRecord(
      propertyID: id,
      entries: [.integer(1)]
    )
    let record2 = makeRecord(
      propertyID: id,
      entries: [.integer(2)]
    )

    try await db.save(record1)
    try await db.save(record2)

    let traces = try await db.loadTraces(for: id)
    #expect(traces.count == 2)
    #expect(traces[0] == ChoiceTrace(entries: [.integer(1)]))
    #expect(traces[1] == ChoiceTrace(entries: [.integer(2)]))
  }

  @Test("Clearing a property removes its traces and leaves others untouched")
  func clearRemovesOnlyTargetProperty() async throws {
    let tempDir = try makeTempDirectory()
    let db = FileBackedDatabase(rootDirectory: tempDir)

    let idA = makePropertyID(fileID: "A.swift", line: 1)
    let idB = makePropertyID(fileID: "B.swift", line: 2)

    try await db.save(makeRecord(propertyID: idA))
    try await db.save(makeRecord(propertyID: idB))

    try await db.clear(for: idA)

    let tracesA = try await db.loadTraces(for: idA)
    let tracesB = try await db.loadTraces(for: idB)

    #expect(tracesA.isEmpty)
    #expect(tracesB.count == 1)
  }

  @Test("Loading a property with no file returns an empty array")
  func loadNonexistentPropertyReturnsEmpty() async throws {
    let tempDir = try makeTempDirectory()
    let db = FileBackedDatabase(rootDirectory: tempDir)
    let id = makePropertyID()

    let traces = try await db.loadTraces(for: id)
    #expect(traces.isEmpty)
  }
}
