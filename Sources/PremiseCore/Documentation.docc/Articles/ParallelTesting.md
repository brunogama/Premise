# Parallel Testing

Run property tests concurrently across multiple CPU cores with PremiseParallel.

## When to Use Parallel Execution

Most property tests run fast enough sequentially. Parallel execution helps when:

- Each run is computationally expensive (e.g. parsing a complex format, running a heavy algorithm)
- You want to maximise machine utilisation in CI on multi-core hardware
- You're running a large number of runs (`maxRuns: 1000+`) and wall-clock time matters

For inexpensive properties, parallel overhead may exceed the savings. Profile before parallelising.

## The ParallelRunner

`PremiseParallel` provides ``ParallelRunner``, which distributes runs across a Swift structured concurrency task group:

```swift
import PremiseCore
import PremiseParallel
import PremiseStrategies

let runner = ParallelRunner(
    strategy: .integers(in: 0...1_000_000),
    config: PropertyConfig(maxRuns: 500),
    parallelConfig: ParallelConfig(maxConcurrentRuns: 8),
    propertyID: PropertyIdentity(fileID: #fileID, line: #line, strategyLabel: "integers")
)

let result = try await runner.run { value in
    // This runs concurrently across up to 8 tasks
    let computed = expensiveFunction(value)
    guard isValid(computed) else {
        throw PropertyViolation("expensiveFunction(\(value)) produced invalid result")
    }
}
```

## Deterministic Seeds

``ParallelRunner`` uses the same seed-per-run formula as sequential ``Runner``:

```
seed for run i = baseSeed + UInt64(i)
```

This means running with the same seed and the same `maxRuns` produces exactly the same set of inputs regardless of whether execution is parallel or sequential. You can reproduce a parallel failure sequentially by using the same seed in a ``Runner``.

## Result Ordering

Even though runs complete in non-deterministic scheduling order, ``ParallelRunner`` always reports the **lowest-index** failure — the same failure you would have seen from sequential execution with the same seed. This is achieved by a private `ResultCollector` actor that tracks the minimum run index seen so far:

```swift
private actor ResultCollector<Value: Sendable> {
    func recordFailure(at index: Int, failure: IndexedFailure<Value>) {
        if let existing = earliestIndex, index >= existing { return }
        earliestIndex = index
        earliestResult = failure
    }
}
```

## ParallelConfig

``ParallelConfig`` controls concurrency:

```swift
public struct ParallelConfig: Sendable {
    /// Max simultaneous tasks. nil = let the runtime decide.
    public var maxConcurrentRuns: Int?

    public static let `default` = ParallelConfig()  // nil — uncapped
}
```

When `maxConcurrentRuns` is `nil`, all runs are submitted to the task group immediately and the Swift runtime schedules them across available cores. Set a limit when you need to control resource usage:

```swift
// Limit to 4 concurrent runs — useful if each run opens file handles
ParallelConfig(maxConcurrentRuns: 4)
```

## Replay-First Semantics

``ParallelRunner`` supports the same replay-first flow as the sequential runner. If you pass a database, stored traces are loaded and replayed *sequentially* before parallel generation begins:

```swift
let database = FileBackedDatabase()
let runner = ParallelRunner(
    strategy: myStrategy,
    config: config,
    database: database
)

// First: replays any stored traces sequentially
// Then: generates new runs in parallel
let result = try await runner.run { value in ... }
```

Replay is sequential by design — replaying in parallel would introduce non-determinism into the replay result.

## Shared State in Property Closures

Because runs execute concurrently, your property closure *must not* use shared mutable state without synchronisation. Closures are `@Sendable` — the compiler will catch obvious violations — but actor-isolated state accessed from many concurrent tasks can become a bottleneck.

```swift
// Bad: race condition — counter is not concurrency-safe
var counter = 0
let result = try await runner.run { value in
    counter += 1  // ← compile error under Swift 6
}

// Good: pure computation per run
let result = try await runner.run { value in
    let result = pureTransform(value)
    guard invariantHolds(result) else { throw PropertyViolation() }
}

// Also fine: actor access (but watch for contention)
let metrics = MetricsActor()
let result = try await runner.run { value in
    await metrics.record(value)
    // ...
}
```

## Comparing with Sequential Execution

| Aspect | Runner (sequential) | ParallelRunner |
|--------|--------------------|----|
| Ordering | Deterministic | Deterministic (lowest-index failure) |
| Speed | Single-core | Multi-core |
| Replay | Yes | Yes (sequential phase) |
| Overhead | None | Task creation per run |
| Best for | Fast properties, CI simplicity | Slow properties, large run counts |
| Database | Via ReplayFirstExecutor | Built-in via `database:` parameter |

## Property Thread Safety Checklist

Before switching to `ParallelRunner`, verify your property closure:

- [ ] Does not mutate shared variables
- [ ] Does not access a non-thread-safe cache or singleton
- [ ] Does not rely on execution order between runs
- [ ] Does not open external resources (files, sockets) without coordination
- [ ] Uses `await` when accessing actor-isolated state

## Next Steps

- Read <doc:SwiftConcurrencySafety> for the full concurrency model.
- Read <doc:TelemetryAndObservability> to observe parallel runs in flight.
