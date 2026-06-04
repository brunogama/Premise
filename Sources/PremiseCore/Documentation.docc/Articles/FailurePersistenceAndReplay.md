# Failure Persistence and Replay

How Premise saves failing traces and replays them automatically on future runs.

## The Problem: Flaky Failures

Property-based tests are random. Without persistence, a test that fails once might not fail again on the next run — the engine just happens to generate different inputs. This is a major problem in CI: a test that fails on a branch might not fail on a rerun, making it hard to confirm a fix.

Premise solves this with **replay-first execution**. Every minimised failure is saved to disk as a ``ChoiceTrace``. On the next run, the engine replays all stored traces *before* generating any fresh inputs. If the failure is still present, it's caught deterministically. If the fix is in place, the replay passes and the stored trace is no longer needed.

## The ExampleDatabase Protocol

``ExampleDatabase`` is the persistence boundary. It lives in `PremiseDatabase` and defines three operations:

```swift
public protocol ExampleDatabase: Actor {
    func loadTraces(for id: PropertyIdentity) async throws -> [ChoiceTrace]
    func save(_ record: FailureRecord) async throws
    func clear(for id: PropertyIdentity) async throws
}
```

`PropertyIdentity` records a property's source file, line, strategy label, and
optional `functionName`. The logical value uses `fileID + functionName +
strategyLabel` for equality and hashing when `functionName` is available, and
falls back to `fileID + line + strategyLabel` otherwise. The adapters pass
`#function`, so failure metadata and in-memory identity comparisons can survive
line movement.

## FileBackedDatabase

The default implementation is ``FileBackedDatabase``. It stores one JSON file per property identity under `.premise/examples/` relative to the current working directory.

The current file-backed physical file name is derived by hex-encoding the
UTF-8 bytes of `"\(fileID)#\(line)#\(strategyLabel)"`, so it is safe on all
file systems. ``SQLiteBackedDatabase`` uses the same three fields in its lookup
index. These storage keys are distinct from logical `PropertyIdentity`
equality/hash behavior, so moving the `forAll` call to another line still
changes replay lookup in the current storage implementations.

```
.premise/
  examples/
    4d79546573742e73776966742334382334...json  ← one file per property
```

Each file contains an array of persisted failure records in the ``PersistenceFormats/PersistedFailureRecordV1`` envelope format.

### Atomic writes

All writes use `Data.write(to:options:[.atomic])`, which writes to a temporary file and renames it into place. This prevents partial-write corruption if the process is killed during a save.

## ReplayFirstExecutor

``ReplayFirstExecutor`` is the bridge that connects the storage-neutral ``Runner`` to the database. The `forAll` functions in `PremiseTesting` and `PremiseXCTest` use it automatically.

```swift
public struct ReplayFirstExecutor<Value: Sendable>: Sendable {
    public init(runner: Runner<Value>, database: any ExampleDatabase)
    public func execute(
        _ property: @escaping @Sendable (Value) throws -> Void
    ) async throws -> RunResult<Value>

    public func executeDetailed(
        _ property: @escaping @Sendable (Value) throws -> Void
    ) async throws -> DetailedRunResult<Value>
}
```

Its `execute` method follows the replay-first flow:

```
1. database.loadTraces(for: runner.propertyID)
2. runner.run(property, replayTraces: loadedTraces)
   ├─ Replay phase: try each stored trace
   └─ If any replay fails → return failure immediately (no fresh generation)
3. If result is .failure: database.save(record)
4. Return result
```

## What Gets Saved

When the engine finds and shrinks a failure, it saves a ``FailureRecord``:

```swift
public struct FailureRecord: Sendable, Codable, Equatable {
    public var propertyID: PropertyIdentity
    public var trace: ChoiceTrace        // the minimized failing trace
    public var errorMessage: String      // the thrown error's description
    public var runCount: Int             // how many runs before this failure
    public var shrinkCount: Int          // how many shrink iterations ran
    public var timestamp: Date           // when the record was created
    public var engineVersion: String     // persistence/engine version
    public var seed: UInt64?             // base seed for reproduction
    public var discovery: FailureDiscovery
    public var statistics: RunStatistics
}
```

The most important field is `trace`. It is the minimal ``ChoiceTrace`` after shrinking. When the executor replays it using ``ReplayProvider``, it deterministically reproduces the exact minimised counterexample.

`discovery` distinguishes newly generated failures from known failures
reproduced from a replay corpus. `statistics` stores notes, events, and target
score observations collected during the failing run.

## JSON Failure Trace Artifacts

In addition to saving replay records in the example database, Premise can export
CI-friendly JSON artifacts. Configure the property with
`exportingFailureTraces(to:)`:

```swift
let config = PropertyConfig.default
    .exportingFailureTraces(to: URL(fileURLWithPath: ".premise/artifacts"))
```

When ``ReplayFirstExecutor`` saves a failure and `traceExportDirectory` is set,
it writes a ``FailureTraceArtifact``:

```swift
public struct FailureTraceArtifact: Sendable, Codable, Equatable {
    public var record: FailureRecord
    public var valueDescription: String?

    public var trace: ChoiceTrace { record.trace }
}
```

The JSON file contains the full ``FailureRecord`` and an optional string
description of the minimized value. Upload these files from CI when you want to
inspect or archive the exact trace that produced a failure without committing
it to the replay corpus yet.

## Failure Lifecycle

Here is the complete lifecycle of a failure across multiple test runs:

```
Run 1 (first failure found):
  Fresh generation → value X fails property
  ShrinkMachine minimises → minimal trace T
  database.save(FailureRecord(trace: T))
  forAll reports: "Found counterexample: <minimal X>"
  ✗ Test fails

Run 2 (before fix is applied):
  database.loadTraces → [T]
  ReplayProvider(T) → same minimal X
  property(X) throws  
  ✗ Test fails (immediately, deterministically)

Run 3 (after fix is applied):
  database.loadTraces → [T]
  ReplayProvider(T) → same minimal X
  property(X) passes  ← fix confirmed
  Fresh generation runs, all pass
  ✓ Test passes

(Stored trace T remains in .premise/examples/)
```

> Note: The stored trace is not automatically deleted when a test passes. This is intentional — the trace serves as a permanent regression case. Delete it manually or via `database.clear(for:)` if you no longer want it replayed.

## Committing Failure Files

The `.premise/examples/` directory should typically be **committed to version control**. This ensures:

- All developers and CI agents replay the same minimised failures
- Fixes are verified against the exact trace that originally failed
- The trace history documents what bugs were found and fixed

Add it to your repository alongside your source code. If you prefer not to commit it, add `.premise/` to `.gitignore` — but be aware that failures will not persist across machines.

## Using a Custom Database

You can provide a custom ``ExampleDatabase`` implementation — for example, one backed by SQLite, an in-memory store for fast CI, or a remote key-value service:

```swift
// Use an in-memory store for isolated unit tests
actor InMemoryDatabase: ExampleDatabase {
    private var storage: [PropertyIdentity: [ChoiceTrace]] = [:]

    func loadTraces(for id: PropertyIdentity) async throws -> [ChoiceTrace] {
        storage[id] ?? []
    }

    func save(_ record: FailureRecord) async throws {
        storage[record.propertyID, default: []].append(record.trace)
    }

    func clear(for id: PropertyIdentity) async throws {
        storage.removeValue(forKey: id)
    }
}

// Wire it into the runner manually
let database = InMemoryDatabase()
let runner = Runner(strategy: myStrategy, config: .default, propertyID: myID)
let executor = ReplayFirstExecutor(runner: runner, database: database)
let result = try await executor.execute { value in ... }
```

## Next Steps

- Read <doc:HowTheEngineWorks> to understand how the trace is constructed during a run.
- Read <doc:ShrinkingExplained> to see how the minimised trace is produced.
- See the tutorial <doc:DebuggingWithReplay> for a hands-on walkthrough.
