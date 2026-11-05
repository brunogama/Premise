import PremiseCore
import PremiseDatabase

/// Deterministic parallel property runner.
///
/// ``ParallelRunner`` distributes property runs across a Swift
/// structured-concurrency task group while preserving deterministic
/// seed-per-index mapping. Each logical run index derives its seed
/// from the base seed using the same formula as ``/PremiseCore/Runner``, so
/// parallel and sequential execution produce identical results for
/// the same seed.
///
/// Completion order is normalized back to logical run index order
/// before evaluating results, ensuring the first failure reported
/// is always the lowest-index failure regardless of scheduling.
///
/// ```swift
/// let runner = ParallelRunner(strategy: intStrategy, config: config)
/// let result = await runner.run { value in
///     // property under test
/// }
/// ```
public struct ParallelRunner<Value: Sendable>: Sendable {
  /// The strategy used to generate values.
  public let strategy: Strategy<Value>

  /// Per-property execution configuration.
  public let config: PropertyConfig

  /// Parallel execution configuration.
  public let parallelConfig: ParallelConfig

  /// Identity of the property under test.
  public let propertyID: PropertyIdentity

  /// Optional shared persistence for replay and failure storage.
  private let database: (any ExampleDatabase)?

  /// Creates a parallel runner.
  ///
  /// - Parameters:
  ///   - strategy: The generation strategy for test values.
  ///   - config: Per-property execution configuration.
  ///   - parallelConfig: Parallel execution configuration.
  ///   - propertyID: Identity of the property under test.
  ///   - database: Optional shared persistence for replay-first
  ///     semantics and failure storage.
  public init(
    strategy: Strategy<Value>,
    config: PropertyConfig = .default,
    parallelConfig: ParallelConfig = .default,
    propertyID: PropertyIdentity = PropertyIdentity(
      fileID: "unknown",
      line: 0,
      strategyLabel: "unknown"
    ),
    database: (any ExampleDatabase)? = nil
  ) {
    self.strategy = strategy
    self.config = config
    self.parallelConfig = parallelConfig
    self.propertyID = propertyID
    self.database = database
  }

  /// Runs the property in parallel with deterministic seed distribution.
  ///
  /// Each logical run index `i` derives its provider seed as
  /// `baseSeed + UInt64(i)`, matching the sequential ``/PremiseCore/Runner``
  /// seed contract. Results are collected by index and the first
  /// failure (lowest index) is returned.
  ///
  /// Replay traces are executed sequentially before parallel
  /// generation begins, preserving replay-first semantics.
  ///
  /// - Parameters:
  ///   - property: The property closure to test.
  ///   - replayTraces: Previously recorded traces to replay first.
  /// - Throws: Any error while loading persisted replay traces.
  /// - Returns: The result of running the property.
  public func run(
    _ property: @escaping @Sendable (Value) throws -> Void,
    replayTraces: [ChoiceTrace] = []
  ) async throws -> RunResult<Value> {
    let allReplayTraces = try await loadReplayTraces(replayTraces)
    if let failure = replayFailure(allReplayTraces, property: property) {
      return .failure(failure.record, value: failure.value)
    }

    let baseSeed = config.seed ?? UInt64.random(in: .min ... .max)
    let result = await generate(baseSeed: baseSeed, property: property)
    if case .failure(let record, value: _) = result, let database {
      try await database.save(record)
    }
    return result
  }

}

private extension ParallelRunner {
  // MARK: - Private

  private func loadReplayTraces(
    _ replayTraces: [ChoiceTrace]
  ) async throws -> [ChoiceTrace] {
    guard let database else { return replayTraces }
    return try await database.loadTraces(for: propertyID) + replayTraces
  }

  private func replayFailure(
    _ traces: [ChoiceTrace],
    property: @Sendable (Value) throws -> Void
  ) -> IndexedFailure<Value>? {
    guard config.replayEnabled else { return nil }
    for trace in traces {
      if let failure = runSingle(trace: trace, property: property) {
        return failure
      }
    }
    return nil
  }

  private func generate(
    baseSeed: UInt64,
    property: @escaping @Sendable (Value) throws -> Void
  ) async -> RunResult<Value> {
    let totalRuns = config.maxRuns
    if totalRuns <= 1 {
      return runSequential(
        baseSeed: baseSeed,
        totalRuns: totalRuns,
        property: property
      )
    }
    return await runParallel(
      baseSeed: baseSeed,
      totalRuns: totalRuns,
      property: property
    )
  }

  /// Parallel fan-out with logical-index normalization.
  private func runParallel(
    baseSeed: UInt64,
    totalRuns: Int,
    property: @escaping @Sendable (Value) throws -> Void
  ) async -> RunResult<Value> {
    let collector = ResultCollector<Value>()
    await collectFailures(collector, baseSeed: baseSeed, property: property)
    guard let failure = await collector.earliestFailure() else {
      return .passed(runs: totalRuns)
    }
    return minimizedResult(
      failure,
      context: (baseSeed, failure.record.runCount),
      property: property
    )
  }

  private func collectFailures(
    _ collector: ResultCollector<Value>,
    baseSeed: UInt64,
    property: @escaping @Sendable (Value) throws -> Void
  ) async {
    let totalRuns = config.maxRuns
    await withTaskGroup(of: Void.self) { group in
      let maxConcurrent = parallelConfig.maxConcurrentRuns ?? totalRuns
      for runIndex in 0..<totalRuns {
        if runIndex >= maxConcurrent { await group.next() }
        group.addTask {
          if let failure = executeIndexed(
            runIndex,
            baseSeed: baseSeed,
            property: property
          ) {
            await collector.recordFailure(at: runIndex, failure: failure)
          }
        }
      }
    }
  }

  private func executeIndexed(
    _ runIndex: Int,
    baseSeed: UInt64,
    property: @Sendable (Value) throws -> Void
  ) -> IndexedFailure<Value>? {
    let provider = PseudoRandomProvider(
      seed: baseSeed &+ UInt64(runIndex),
      maxDraws: config.maxDrawsPerRun
    )
    return executeSingle(provider: provider, property: property)
  }

  /// Sequential fallback for small run counts.
  private func runSequential(
    baseSeed: UInt64,
    totalRuns: Int,
    property: @escaping @Sendable (Value) throws -> Void
  ) -> RunResult<Value> {
    for runIndex in 0..<totalRuns {
      if let failure = executeIndexed(
        runIndex,
        baseSeed: baseSeed,
        property: property
      ) {
        return minimizedResult(
          failure,
          context: (baseSeed, runIndex + 1),
          property: property
        )
      }
    }
    return .passed(runs: totalRuns)
  }

}

private extension ParallelRunner {
  // MARK: - Minimisation

  private func minimizedResult(
    _ failure: IndexedFailure<Value>,
    context: (seed: UInt64, runCount: Int),
    property: @escaping @Sendable (Value) throws -> Void
  ) -> RunResult<Value> {
    let runner = Runner(
      strategy: strategy,
      config: config,
      propertyID: propertyID
    )
    let minimized = runner.minimizeTrace(
      initialTrace: failure.record.trace,
      errorMessage: failure.record.errorMessage,
      initialValue: failure.value,
      runCount: context.runCount,
      property: property,
      seed: context.seed,
      statistics: failure.record.statistics
    )
    return .failure(minimized.record, value: minimized.value)
  }

  /// Replays a single trace against the property.
  private func runSingle(
    trace: ChoiceTrace,
    property: @Sendable (Value) throws -> Void
  ) -> IndexedFailure<Value>? {
    let provider = ReplayProvider(trace: trace)
    return executeSingle(provider: provider, property: property)
  }

  /// Executes a single run with the given provider.
  private func executeSingle(
    provider: some PrimitiveProvider,
    property: @Sendable (Value) throws -> Void
  ) -> IndexedFailure<Value>? {
    var data = PremiseData(provider: provider)
    var drawnValue: Value?
    do {
      let value = try strategy.draw(&data)
      drawnValue = value
      try property(value)
      return nil
    } catch {
      return makeFailure(error, data: &data, value: drawnValue)
    }
  }

  private func makeFailure(
    _ error: any Error,
    data: inout PremiseData,
    value: Value?
  ) -> IndexedFailure<Value>? {
    let record = FailureRecord(
      propertyID: propertyID,
      trace: data.snapshot(),
      errorMessage: String(describing: error),
      runCount: 1,
      shrinkCount: 0,
      statistics: data.statistics
    )
    guard let value else { return nil }
    return IndexedFailure(record: record, value: value)
  }
}
