import ConjectureCore

/// Storage boundary shared by file-backed and future database implementations.
public protocol ExampleDatabase: Actor {
  func loadTraces(for id: PropertyIdentity) async throws -> [ChoiceTrace]
  func save(_ record: FailureRecord) async throws
  func clear(for id: PropertyIdentity) async throws
}
