import PremiseCore
import PremiseDatabase
import PremiseParallel
import PremiseStrategies
import Foundation
import Testing

@Suite("Parallel Determinism Tests")
struct ParallelDeterminismTests {

  /// Strategy that draws a single integer in 0...1000.
  private var intStrategy: Strategy<Int> {
    Strategy<Int>(label: "int") { data in
      data.drawInteger(in: 0...1000)
    }
  }

  @Test("Same seed produces identical results in parallel and sequential mode")
  func sameSeedSameResult() async throws {
    let seed: UInt64 = 42
    let config = PropertyConfig(maxRuns: 50, seed: seed)

    let property: @Sendable (Int) throws -> Void = { value in
      if value > 900 {
        throw PropertyFailure(message: "too large: \(value)")
      }
    }
    // Sequential run via core Runner.
    let sequentialRunner = Runner(strategy: intStrategy, config: config)
    let sequentialResult = await sequentialRunner.run(property)

    // Parallel run via ParallelRunner.
    let parallelRunner = ParallelRunner(
      strategy: intStrategy,
      config: config,
      parallelConfig: ParallelConfig(maxConcurrentRuns: 4)
    )
    let parallelResult = try await parallelRunner.run(property)

    // Both must agree on pass/fail.
    expectMatchingResults(
      sequentialResult,
      parallelResult,
      disagreement: "Sequential and parallel results disagree"
    )
  }

  @Test("Parallel runner returns lowest-index failure regardless of scheduling")
  func lowestIndexFailure() async throws {
    // Use a seed and property where multiple indices fail.
    // The property fails on any even value, so many runs will fail.
    let seed: UInt64 = 123
    let config = PropertyConfig(maxRuns: 20, seed: seed)

    let parallelRunner = ParallelRunner(
      strategy: intStrategy,
      config: config,
      parallelConfig: ParallelConfig(maxConcurrentRuns: 8)
    )

    // Run multiple times; the result should be deterministic.
    var firstResult: (String, Int)?
    for _ in 0..<5 {
      let result = try await parallelRunner.run { value in
        if value % 2 == 0 {
          throw PropertyFailure(message: "even: \(value)")
        }
      }

      recordFirstFailure(result, firstResult: &firstResult)
    }

    // At least one run should have failed (even values are common).
    #expect(firstResult != nil, "Expected at least one failure")
  }

  @Test("Parallel runner passes when all runs pass")
  func allRunsPass() async throws {
    let config = PropertyConfig(maxRuns: 30, seed: 99)
    let parallelRunner = ParallelRunner(
      strategy: intStrategy,
      config: config
    )

    let result = try await parallelRunner.run { _ in
      // Always passes.
    }

    guard case .passed(let runs) = result else {
      Issue.record("Expected all runs to pass")
      return
    }
    #expect(runs == 30)
  }

  @Test("Parallel runner with single run works correctly")
  func singleRun() async throws {
    let config = PropertyConfig(maxRuns: 1, seed: 7)
    let parallelRunner = ParallelRunner(
      strategy: intStrategy,
      config: config
    )

    let result = try await parallelRunner.run { _ in
      // Always passes.
    }

    guard case .passed(let runs) = result else {
      Issue.record("Expected single run to pass")
      return
    }
    #expect(runs == 1)
  }

}

extension ParallelDeterminismTests {
  @Test("Parallel runner replays traces before generation")
  func replayBeforeGeneration() async throws {
    let seed: UInt64 = 55
    let config = PropertyConfig(maxRuns: 10, seed: seed, replayEnabled: true)

    // Create a trace that will replay a known value.
    let replayTrace = ChoiceTrace(entries: [.integer(999)])

    let parallelRunner = ParallelRunner(
      strategy: intStrategy,
      config: config
    )

    let result = try await parallelRunner.run(
      { value in
        if value == 999 {
          throw PropertyFailure(message: "replayed failure")
        }
      },
      replayTraces: [replayTrace]
    )

    guard case .failure(let record, value: _) = result else {
      Issue.record("Expected replay to trigger failure")
      return
    }
    #expect(record.errorMessage.contains("replayed failure"))
  }

  @Test(
    "Seed-per-index mapping matches sequential Runner for failure detection"
  )
  func seedPerIndexMatchesSequential() async throws {
    // Use a deterministic property that fails on specific seed-derived values.
    // Both runners use the same seed formula: baseSeed + UInt64(runIndex).
    let config = PropertyConfig(maxRuns: 20, seed: 77)

    // A property that fails when the drawn value exceeds a threshold.
    let threshold = 800
    let property: @Sendable (Int) throws -> Void = { value in
      if value > threshold {
        throw PropertyFailure(message: "over \(threshold): \(value)")
      }
    }
    let seqRunner = Runner(strategy: intStrategy, config: config)
    let seqResult = await seqRunner.run(property)

    let parRunner = ParallelRunner(
      strategy: intStrategy,
      config: config,
      parallelConfig: ParallelConfig(maxConcurrentRuns: 4)
    )
    let parResult = try await parRunner.run(property)

    // Both runners must agree on pass/fail outcome.
    expectMatchingResults(
      seqResult,
      parResult,
      disagreement: "Sequential and parallel results disagree on pass/fail"
    )
  }

  @Test("Parallel runner persists failures to shared database")
  func persistsFailuresToDatabase() async throws {
    let tmpDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("parallel-persist-\(UUID().uuidString)")
    let database = FileBackedDatabase(rootDirectory: tmpDir)

    let pid = PropertyIdentity(
      fileID: "persist-test",
      line: 1,
      strategyLabel: "int"
    )
    let runner = persistentRunner(database: database, propertyID: pid)

    let result = try await runner.run { value in
      if value > 500 {
        throw PropertyFailure(message: "too large: \(value)")
      }
    }

    // If it failed, the failure should be persisted.
    if case .failure = result {
      let traces = try await database.loadTraces(for: pid)
      #expect(!traces.isEmpty, "Failure should be persisted to the database")
    }

    try? FileManager.default.removeItem(at: tmpDir)
  }
}

private extension ParallelDeterminismTests {
  func expectMatchingResults(
    _ sequential: RunResult<Int>,
    _ parallel: RunResult<Int>,
    disagreement: String
  ) {
    switch (sequential, parallel) {
    case (.passed, .passed):
      break
    case (
      .failure(let seqRec, value: let seqVal),
      .failure(let parRec, value: let parVal)
    ):
      #expect(seqRec.errorMessage == parRec.errorMessage)
      #expect(seqVal == parVal)
    default:
      Issue.record(Comment(rawValue: disagreement))
    }
  }

  func recordFirstFailure(
    _ result: RunResult<Int>,
    firstResult: inout (String, Int)?
  ) {
    if case .failure(let record, value: let value) = result {
      let current = (record.errorMessage, value)
      if let prev = firstResult {
        #expect(prev.0 == current.0, "Error message must be stable across runs")
        #expect(prev.1 == current.1, "Failing value must be stable across runs")
      } else {
        firstResult = current
      }
    }
  }

  func persistentRunner(
    database: FileBackedDatabase,
    propertyID: PropertyIdentity
  ) -> ParallelRunner<Int> {
    let config = PropertyConfig(maxRuns: 20, seed: 42)
    return ParallelRunner(
      strategy: intStrategy,
      config: config,
      parallelConfig: ParallelConfig(maxConcurrentRuns: 4),
      propertyID: propertyID,
      database: database
    )
  }
}

/// Simple error type for test properties.
private struct PropertyFailure: Error {
  let message: String
}
