import ConjectureCore

/// Executes a property test through the replay-first flow: persisted traces
/// are loaded and replayed before any fresh generation occurs.
///
/// This type bridges the gap between `ConjectureCore` (which is
/// storage-neutral) and `ConjectureDatabase` (which owns persistence).
/// The executor loads traces from an ``ExampleDatabase``, passes them to
/// the runner, and persists any new failure back to the database.
public struct ReplayFirstExecutor<Value: Sendable>: Sendable {

    /// The runner that drives trace replay and fresh generation.
    private let runner: Runner<Value>

    /// The database used to load and persist failure records.
    private let database: any ExampleDatabase

    /// Creates a replay-first executor.
    ///
    /// - Parameters:
    ///   - runner: The property runner whose ``Runner/run(_:replayTraces:)``
    ///     method will be called.
    ///   - database: The database from which traces are loaded and to which
    ///     new failures are saved.
    public init(runner: Runner<Value>, database: any ExampleDatabase) {
        self.runner = runner
        self.database = database
    }

    /// Executes the property through the replay-first flow.
    ///
    /// 1. Loads persisted traces from the database for the runner's property
    ///    identity.
    /// 2. Passes the loaded traces to ``Runner/run(_:replayTraces:)``.
    /// 3. If the result is a failure, persists the failure record back to the
    ///    database for future runs.
    /// 4. Returns the original ``RunResult`` unchanged.
    ///
    /// - Parameter property: The property closure to test.
    /// - Returns: The result of executing the property.
    public func execute(
        _ property: @Sendable (Value) throws -> Void
    ) async throws -> RunResult<Value> {
        let traces = try await database.loadTraces(for: runner.propertyID)
        let result = await runner.run(property, replayTraces: traces)

        if case .failure(let record, value: _) = result {
            try await database.save(record)
        }

        return result
    }
}
