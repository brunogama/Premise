import PremiseCore

/// Example database that reads replay traces from ordered sources and writes
/// new failures to a single writable database.
public actor CompositeExampleDatabase: ExampleDatabase {
  private let replaySources: [any ExampleDatabase]
  private let writableDatabase: any ExampleDatabase

  /// Creates a database with ordered replay sources and a writable store.
  public init(
    replaySources: [any ExampleDatabase],
    writableDatabase: any ExampleDatabase
  ) {
    self.replaySources = replaySources
    self.writableDatabase = writableDatabase
  }

  /// Loads traces from each replay source in order.
  public func loadTraces(
    for id: PropertyIdentity
  ) async throws -> [ChoiceTrace] {
    var traces: [ChoiceTrace] = []
    for source in replaySources {
      traces.append(contentsOf: try await source.loadTraces(for: id))
    }
    return traces
  }

  /// Stores a failure in the writable database.
  public func save(_ record: FailureRecord) async throws {
    try await writableDatabase.save(record)
  }

  /// Removes stored failures from the writable database.
  public func clear(for id: PropertyIdentity) async throws {
    try await writableDatabase.clear(for: id)
  }
}
