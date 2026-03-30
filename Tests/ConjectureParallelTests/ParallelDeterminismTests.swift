import ConjectureCore
import ConjectureParallel
import ConjectureStrategies
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
    func sameSeedSameResult() async {
        let seed: UInt64 = 42
        let config = PropertyConfig(maxRuns: 50, seed: seed)

        // Sequential run via core Runner.
        let sequentialRunner = Runner(strategy: intStrategy, config: config)
        let sequentialResult = await sequentialRunner.run { value in
            if value > 900 {
                throw PropertyFailure(message: "too large: \(value)")
            }
        }

        // Parallel run via ParallelRunner.
        let parallelRunner = ParallelRunner(
            strategy: intStrategy,
            config: config,
            parallelConfig: ParallelConfig(maxConcurrentRuns: 4)
        )
        let parallelResult = await parallelRunner.run { value in
            if value > 900 {
                throw PropertyFailure(message: "too large: \(value)")
            }
        }

        // Both must agree on pass/fail.
        switch (sequentialResult, parallelResult) {
        case (.passed, .passed):
            break  // Both passed, expected.

        case (.failure(let seqRec, value: let seqVal), .failure(let parRec, value: let parVal)):
            // Both must find the same error message (from the same seed+index).
            #expect(seqRec.errorMessage == parRec.errorMessage)
            #expect(seqVal == parVal)

        default:
            Issue.record("Sequential and parallel results disagree")
        }
    }

    @Test("Parallel runner returns lowest-index failure regardless of scheduling")
    func lowestIndexFailure() async {
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
            let result = await parallelRunner.run { value in
                if value % 2 == 0 {
                    throw PropertyFailure(message: "even: \(value)")
                }
            }

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

        // At least one run should have failed (even values are common).
        #expect(firstResult != nil, "Expected at least one failure")
    }

    @Test("Parallel runner passes when all runs pass")
    func allRunsPass() async {
        let config = PropertyConfig(maxRuns: 30, seed: 99)
        let parallelRunner = ParallelRunner(
            strategy: intStrategy,
            config: config
        )

        let result = await parallelRunner.run { _ in
            // Always passes.
        }

        guard case .passed(let runs) = result else {
            Issue.record("Expected all runs to pass")
            return
        }
        #expect(runs == 30)
    }

    @Test("Parallel runner with single run works correctly")
    func singleRun() async {
        let config = PropertyConfig(maxRuns: 1, seed: 7)
        let parallelRunner = ParallelRunner(
            strategy: intStrategy,
            config: config
        )

        let result = await parallelRunner.run { _ in
            // Always passes.
        }

        guard case .passed(let runs) = result else {
            Issue.record("Expected single run to pass")
            return
        }
        #expect(runs == 1)
    }

    @Test("Parallel runner replays traces before generation")
    func replayBeforeGeneration() async {
        let seed: UInt64 = 55
        let config = PropertyConfig(maxRuns: 10, seed: seed, replayEnabled: true)

        // Create a trace that will replay a known value.
        let replayTrace = ChoiceTrace(entries: [.integer(999)])

        let parallelRunner = ParallelRunner(
            strategy: intStrategy,
            config: config
        )

        let result = await parallelRunner.run(
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

    @Test("Seed-per-index mapping matches sequential Runner for failure detection")
    func seedPerIndexMatchesSequential() async {
        // Use a deterministic property that fails on specific seed-derived values.
        // Both runners use the same seed formula: baseSeed + UInt64(runIndex).
        let seed: UInt64 = 77
        let maxRuns = 20
        let config = PropertyConfig(maxRuns: maxRuns, seed: seed)

        // A property that fails when the drawn value exceeds a threshold.
        let threshold = 800
        let seqRunner = Runner(strategy: intStrategy, config: config)
        let seqResult = await seqRunner.run { value in
            if value > threshold {
                throw PropertyFailure(message: "over \(threshold): \(value)")
            }
        }

        let parRunner = ParallelRunner(
            strategy: intStrategy,
            config: config,
            parallelConfig: ParallelConfig(maxConcurrentRuns: 4)
        )
        let parResult = await parRunner.run { value in
            if value > threshold {
                throw PropertyFailure(message: "over \(threshold): \(value)")
            }
        }

        // Both runners must agree on pass/fail outcome.
        switch (seqResult, parResult) {
        case (.passed, .passed):
            break

        case (.failure(let seqRec, value: let seqVal), .failure(let parRec, value: let parVal)):
            #expect(seqRec.errorMessage == parRec.errorMessage)
            #expect(seqVal == parVal)

        default:
            Issue.record("Sequential and parallel results disagree on pass/fail")
        }
    }
}

/// Simple error type for test properties.
private struct PropertyFailure: Error {
    let message: String
}
