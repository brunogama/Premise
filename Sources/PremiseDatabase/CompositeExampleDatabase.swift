import PremiseCore

/// Example database that reads replay traces from ordered sources and writes
/// new failures to a single writable database.
public actor CompositeExampleDatabase: ExampleDatabase {
  private let replaySources: [any ExampleDatabase]
  private let writableDatabase: any ExampleDatabase

  public init(
    replaySources: [any ExampleDatabase],
    writableDatabase: any ExampleDatabase
  ) {
    self.replaySources = replaySources
    self.writableDatabase = writableDatabase
  }

  public func loadTraces(for id: PropertyIdentity) async throws -> [ChoiceTrace] {
    var traces: [ChoiceTrace] = []
    for source in replaySources {
      traces.append(contentsOf: try await source.loadTraces(for: id))
    }
    return traces
  }

  public func save(_ record: FailureRecord) async throws {
    try await writableDatabase.save(record)
  }

  public func clear(for id: PropertyIdentity) async throws {
    try await writableDatabase.clear(for: id)
  }
}
