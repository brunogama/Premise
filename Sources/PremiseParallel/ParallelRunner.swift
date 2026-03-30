import PremiseCore
import PremiseDatabase

/// Deterministic parallel property runner.
///
/// ``ParallelRunner`` distributes property runs across a Swift
/// structured-concurrency task group while preserving deterministic
/// seed-per-index mapping. Each logical run index derives its seed
/// from the base seed using the same formula as ``Runner``, so
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
  /// `baseSeed + UInt64(i)`, matching the sequential ``Runner``
  /// seed contract. Results are collected by index and the first
  /// failure (lowest index) is returned.
  ///
  /// Replay traces are executed sequentially before parallel
  /// generation begins, preserving replay-first semantics.
  ///
  /// - Parameters:
  ///   - property: The property closure to test.
  ///   - replayTraces: Previously recorded traces to replay first.
  /// - Returns: The result of running the property.
  public func run(
    _ property: @escaping @Sendable (Value) throws -> Void,
    replayTraces: [ChoiceTrace] = []
  ) async throws -> RunResult<Value> {
    // Load persisted traces from the database when available.
    var allReplayTraces = replayTraces
    if let database {
      let stored = try await database.loadTraces(for: propertyID)
      allReplayTraces = stored + replayTraces
    }

    // Replay phase: sequential, matching Runner semantics.
    if config.replayEnabled {
      for trace in allReplayTraces {
        if let failure = runSingle(trace: trace, property: property) {
          return .failure(failure.record, value: failure.value)
        }
      }
    }

    // Use a random seed when none is specified so each invocation
    // independently explores the input space.  The seed is stored in
    // the FailureRecord so failures are always reproducible.
    let baseSeed = config.seed ?? UInt64.random(in: .min ... .max)
    let totalRuns = config.maxRuns

    // For very small run counts, avoid task group overhead.
    let result: RunResult<Value>
    if totalRuns <= 1 {
      result = runSequential(baseSeed: baseSeed, totalRuns: totalRuns, property: property)
    } else {
      result = await runParallel(baseSeed: baseSeed, totalRuns: totalRuns, property: property)
    }

    // Persist failures back to the shared database.
    if case .failure(let record, value: _) = result, let database {
      try await database.save(record)
    }

    return result
  }

  // MARK: - Private

  /// Parallel fan-out with logical-index normalization.
  private func runParallel(
    baseSeed: UInt64,
    totalRuns: Int,
    property: @escaping @Sendable (Value) throws -> Void
  ) async -> RunResult<Value> {
    // Track the first (lowest-index) failure found.
    // We use an actor to safely collect results across tasks.
    let collector = ResultCollector<Value>(totalRuns: totalRuns)

    await withTaskGroup(of: Void.self) { group in
      let maxConcurrent = parallelConfig.maxConcurrentRuns ?? totalRuns

      for runIndex in 0..<totalRuns {
        // Throttle if max concurrent runs is set.
        if runIndex >= maxConcurrent {
          await group.next()
        }

        let seedForIndex = baseSeed &+ UInt64(runIndex)
        let maxDraws = config.maxDrawsPerRun
        let capturedStrategy = strategy
        let capturedPropertyID = propertyID

        group.addTask {
          let provider = PseudoRandomProvider(
            seed: seedForIndex,
            maxDraws: maxDraws
          )
          let result = Self.executeSingle(
            provider: provider,
            strategy: capturedStrategy,
            propertyID: capturedPropertyID,
            property: property
          )
          if let failure = result {
            await collector.recordFailure(at: runIndex, failure: failure)
          }
        }
      }
    }

    if let earliest = await collector.earliestFailure() {
      let minimized = minimizeTrace(
        initialTrace: earliest.record.trace,
        errorMessage: earliest.record.errorMessage,
        initialValue: earliest.value,
        runCount: earliest.record.runCount,
        property: property,
        seed: baseSeed
      )
      return .failure(minimized.record, value: minimized.value)
    }

    return .passed(runs: totalRuns)
  }

  /// Sequential fallback for small run counts.
  private func runSequential(
    baseSeed: UInt64,
    totalRuns: Int,
    property: @Sendable (Value) throws -> Void
  ) -> RunResult<Value> {
    for runIndex in 0..<totalRuns {
      let seedForIndex = baseSeed &+ UInt64(runIndex)
      let provider = PseudoRandomProvider(
        seed: seedForIndex,
        maxDraws: config.maxDrawsPerRun
      )
      if let failure = Self.executeSingle(
        provider: provider,
        strategy: strategy,
        propertyID: propertyID,
        property: property
      ) {
        let minimized = minimizeTrace(
          initialTrace: failure.record.trace,
          errorMessage: failure.record.errorMessage,
          initialValue: failure.value,
          runCount: runIndex + 1,
          property: property,
          seed: baseSeed
        )
        return .failure(minimized.record, value: minimized.value)
      }
    }
    return .passed(runs: totalRuns)
  }

  // MARK: - Minimisation

  /// Runs ``ShrinkMachine`` on `initialTrace` and returns the smallest
  /// failing counterexample together with an updated ``FailureRecord``.
  private func minimizeTrace(
    initialTrace: ChoiceTrace,
    errorMessage: String,
    initialValue: Value,
    runCount: Int,
    property: @escaping @Sendable (Value) throws -> Void,
    seed: UInt64?
  ) -> (record: FailureRecord, value: Value) {
    // Delegate to a Runner for shrinking — Runner already has the
    // full ShrinkMachine integration.
    let runner = Runner(
      strategy: strategy,
      config: config,
      propertyID: propertyID
    )
    return runner.minimizeTrace(
      initialTrace: initialTrace,
      errorMessage: errorMessage,
      initialValue: initialValue,
      runCount: runCount,
      property: property,
      seed: seed
    )
  }

  /// Replays a single trace against the property.
  private func runSingle(
    trace: ChoiceTrace,
    property: @Sendable (Value) throws -> Void
  ) -> IndexedFailure<Value>? {
    let provider = ReplayProvider(trace: trace)
    return Self.executeSingle(
      provider: provider,
      strategy: strategy,
      propertyID: propertyID,
      property: property
    )
  }

  /// Executes a single run with the given provider.
  private static func executeSingle(
    provider: some PrimitiveProvider,
    strategy: Strategy<Value>,
    propertyID: PropertyIdentity,
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
      let record = FailureRecord(
        propertyID: propertyID,
        trace: data.snapshot(),
        errorMessage: String(describing: error),
        runCount: 1,
        shrinkCount: 0
      )
      guard let drawnValue else {
        return nil
      }
      return IndexedFailure(record: record, value: drawnValue)
    }
  }
}

/// Failure record paired with the drawn value for result normalization.
struct IndexedFailure<Value: Sendable>: Sendable {
  let record: FailureRecord
  let value: Value
}

/// Actor that collects failures from parallel tasks and tracks the
/// earliest (lowest-index) failure for deterministic result ordering.
private actor ResultCollector<Value: Sendable> {
  private let totalRuns: Int
  private var earliestIndex: Int?
  private var earliestResult: IndexedFailure<Value>?

  init(totalRuns: Int) {
    self.totalRuns = totalRuns
  }

  func recordFailure(at index: Int, failure: IndexedFailure<Value>) {
    if let existing = earliestIndex, index >= existing {
      return
    }
    earliestIndex = index
    earliestResult = failure
  }

  func earliestFailure() -> IndexedFailure<Value>? {
    earliestResult
  }
}
