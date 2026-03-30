# Architecture Patterns

**Domain:** Swift-native property-based testing framework
**Researched:** 2026-03-30
**Confidence:** HIGH for package layering, concurrency isolation, and persistence boundaries; MEDIUM for runtime coverage-guidance implementation details because the current Swift/LLVM toolchain exposes source-based coverage primarily as a post-run artifact.

## Recommended Architecture

Conjecture should be one Swift package with a strict one-way target graph. `ConjectureCore` owns the engine, trace semantics, replay inputs, shrink orchestration, and provider-facing execution contracts. `ConjectureStrategies` owns compositional strategy witnesses and the standard strategy catalog. `ConjectureDatabase` owns versioned persistence envelopes, migrations, and the single actor that serializes all file or SQLite access. `ConjectureTesting` and `ConjectureXCTest` stay thin and only translate between test-framework expectations and the shared core runner.

That shape fits the current SwiftPM model well. The PackageDescription docs still describe targets as the basic module boundary and products as assemblies of targets, and the current `swift build` / `swift test` toolchain exposes `--explicit-target-dependency-import-check`, which is the right guardrail to stop layer violations before they become architectural drift. Conjecture should lean into that: explicit target dependencies in `Package.swift`, no by-name shortcuts for internal layers, and CI that fails on undeclared imports.

For concurrency, keep the hot path synchronous and value-oriented. Swift 6 mode enables full data-race safety checking for package targets, and Swift 6.2 changes around `nonisolated` async execution make implicit behavior easier to get wrong if public APIs are vague. The engine loop, trace building, replay, and shrinking should therefore be synchronous functions over `struct` state and `Sendable` witnesses. Actors belong at the edges: persistence, optional telemetry aggregation, and any future shared coverage frontier. Public async APIs that intentionally inherit caller isolation should spell that explicitly; do not rely on evolving defaults.

For v2, add leaf targets instead of reopening v1 seams. SQLite WAL persistence, parallel execution, coverage-guided exploration, telemetry hooks, and SMT-backed providers should each plug into existing storage, scheduling, or provider boundaries. The core rule is simple: v2 modules may depend inward on stable v1 contracts, but v1 modules must not grow back-edges to satisfy v2.

### Target Graph

```text
ConjectureCore
├── ConjectureStrategies
├── ConjectureDatabase
│   └── ConjectureSQLite (v2)
├── ConjectureTesting
├── ConjectureXCTest
├── ConjectureCoverage (v2)
├── ConjectureParallel (v2)
├── ConjectureTelemetry (v2)
└── ConjectureSMT (v2)
```

Recommended dependency directions:

- `ConjectureStrategies` -> `ConjectureCore`
- `ConjectureDatabase` -> `ConjectureCore`
- `ConjectureTesting` -> `ConjectureCore`, `ConjectureStrategies`, `ConjectureDatabase`
- `ConjectureXCTest` -> `ConjectureCore`, `ConjectureStrategies`, `ConjectureDatabase`
- `ConjectureSQLite` -> `ConjectureDatabase`
- `ConjectureCoverage` -> `ConjectureCore`, `ConjectureDatabase`
- `ConjectureParallel` -> `ConjectureCore`, `ConjectureDatabase`, optionally `ConjectureCoverage`
- `ConjectureTelemetry` -> `ConjectureCore`, optionally `ConjectureDatabase`
- `ConjectureSMT` -> `ConjectureCore`, optionally `ConjectureStrategies`

If SQLite C interop needs its own target, make it an internal implementation detail behind `ConjectureSQLite` rather than a public-facing product.

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `ConjectureCore` | Engine state machine, choice trace, replay cursor, shrink orchestration, deterministic run outcomes, provider/witness contracts, stable semantic trace model | Called by adapters, strategies, database codecs, and v2 leaf modules |
| `ConjectureStrategies` | Public strategy builders, combinators, recursive composition helpers, witness factories, domain-specific generation conveniences | Depends on `ConjectureCore` only |
| `ConjectureDatabase` | Versioned failure/trace envelopes, file-backed persistence for v1, actor-owned storage facade, migration hooks, replay lookup APIs | Consumes `ConjectureCore` trace/outcome types; used by adapters and v2 storage modules |
| `ConjectureTesting` | `swift-testing` integration, attachments, assertion translation, property author ergonomics | Calls `ConjectureCore`, `ConjectureStrategies`, `ConjectureDatabase` |
| `ConjectureXCTest` | XCTest integration, failure formatting, replay helpers for XCTest users | Calls `ConjectureCore`, `ConjectureStrategies`, `ConjectureDatabase` |
| `ConjectureSQLite` (v2) | SQLite-backed storage engine, WAL/checkpoint policy, indexes for replay/failure lookup, storage implementation behind database facade | Implements `ConjectureDatabase` storage contract |
| `ConjectureCoverage` (v2) | Coverage artifact import, frontier scoring, guidance snapshots, optional feedback signals for scheduler/provider selection | Reads persisted run metadata; feeds ranked guidance to `ConjectureParallel` or adapters |
| `ConjectureParallel` (v2) | Task-group scheduling, worker isolation, seed distribution, result fan-in, cancellation policy | Runs isolated `ConjectureCore` workers; writes through `ConjectureDatabase`; optionally reads `ConjectureCoverage` |
| `ConjectureTelemetry` (v2) | Structured events, metrics sinks, trace/run counters, observability hooks | Subscribes to core outcomes and persistence events without affecting engine control flow |
| `ConjectureSMT` (v2) | Optional solver-backed provider implementations that satisfy existing core/provider seams | Implements `ConjectureCore` provider contracts |

## Data Flow

### v1 execution flow

1. A user-facing adapter in `ConjectureTesting` or `ConjectureXCTest` builds a property plan from strategy witnesses and runner configuration.
2. `ConjectureCore` executes the property with a synchronous engine loop that records a semantic `Trace` and an outcome.
3. If the run fails, `ConjectureCore` shrinks using the same trace-first model and emits a final minimized failure artifact.
4. The adapter sends that artifact to the `ConjectureDatabase` actor.
5. `ConjectureDatabase` writes a versioned envelope to the v1 file backend and returns a stable replay handle.
6. Replay goes back through `ConjectureDatabase` to recover the persisted envelope, then into `ConjectureCore` to deterministically rerun from the trace.

```text
Adapter -> Strategy Witnesses -> Core Runner -> Trace/Outcome
                                             |
                                             v
                                   Database Actor (v1 files)
                                             |
                                             v
                                       Replay Handle
```

### v2 extension flow

1. `ConjectureParallel` starts multiple isolated worker tasks, each with its own engine state, seed, and trace buffer.
2. Workers never share mutable engine state. Shared resources are actor-owned services only: persistence, optional telemetry, optional coverage frontier.
3. `ConjectureSQLite` replaces the v1 file backend behind the database facade without changing adapter or core call sites.
4. `ConjectureCoverage` ingests coverage artifacts or alternate feedback out of band, updates guidance state, and hands snapshots to the next scheduling pass.

```text
Parallel Scheduler -> N isolated Core workers
                       |        |        |
                       +--------+--------+
                                |
                                v
                   Database Actor -> File backend (v1)
                                  -> SQLite backend (v2)

Coverage import -> Coverage Actor -> Scheduler snapshot for future runs
```

## Suggested Build Order

1. **Freeze the target graph first**
   - Create all public v1 targets immediately, even if some start mostly empty.
   - Add explicit target dependencies in `Package.swift`.
   - Turn on `--explicit-target-dependency-import-check error` in CI from day one to keep boundaries honest.

2. **Build `ConjectureCore` before anything else**
   - Define trace semantics, replay cursor, shrink orchestration, deterministic runner state, and provider contracts.
   - Keep the public API synchronous where possible.

3. **Build `ConjectureStrategies` on top of frozen core contracts**
   - Standardize the protocol-witness shape here, not in adapters.
   - Require witness containers to be `Sendable` so v2 parallelism does not force a redesign.

4. **Build `ConjectureDatabase` before the adapters become feature-rich**
   - Ship the v1 file-backed implementation inside an actor-owned facade.
   - Freeze stable persistence envelopes and replay handles now.
   - Keep all on-disk versioning and migrations here, not in `ConjectureCore`.

5. **Build `ConjectureTesting` and `ConjectureXCTest` last in v1**
   - Keep them thin: authoring sugar, failure presentation, attachments, and replay ergonomics only.
   - They should not invent engine semantics, persistence rules, or shrink behavior.

6. **Add v2 as inward-facing leaves**
   - `ConjectureSQLite` first, because it replaces storage plumbing without changing the core.
   - `ConjectureParallel` next, because the engine and witnesses are already `Sendable`.
   - `ConjectureCoverage` after that, because current Swift/LLVM coverage flows are post-run and should remain a sidecar.
   - `ConjectureTelemetry` and `ConjectureSMT` last, as optional integrations.

## Patterns to Follow

### Pattern 1: Explicit dependency-only layering
**What:** Every target declares only the modules it is allowed to import, and CI enforces that those imports are explicit.
**When:** Immediately, in the first package manifest.
**Example:**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Conjecture",
    products: [
        .library(name: "ConjectureCore", targets: ["ConjectureCore"]),
        .library(name: "ConjectureStrategies", targets: ["ConjectureStrategies"]),
        .library(name: "ConjectureDatabase", targets: ["ConjectureDatabase"]),
        .library(name: "ConjectureTesting", targets: ["ConjectureTesting"]),
        .library(name: "ConjectureXCTest", targets: ["ConjectureXCTest"]),
    ],
    targets: [
        .target(name: "ConjectureCore"),
        .target(name: "ConjectureStrategies", dependencies: ["ConjectureCore"]),
        .target(name: "ConjectureDatabase", dependencies: ["ConjectureCore"]),
        .target(
            name: "ConjectureTesting",
            dependencies: ["ConjectureCore", "ConjectureStrategies", "ConjectureDatabase"]
        ),
        .target(
            name: "ConjectureXCTest",
            dependencies: ["ConjectureCore", "ConjectureStrategies", "ConjectureDatabase"]
        ),
    ]
)
```

### Pattern 2: Synchronous engine, async edges
**What:** The engine loop and witness execution stay synchronous and allocation-light; actors and async calls are reserved for persistence and other shared services.
**When:** All hot-path code in `ConjectureCore` and `ConjectureStrategies`.
**Example:**

```swift
public struct StrategyWitness<Value: Sendable>: Sendable {
    public let draw: @Sendable (inout EngineContext) throws -> Value
    public let replay: @Sendable (inout ReplayContext) throws -> Value
    public let shrink: @Sendable (Value, TraceSlice) -> AnyIterator<Value>
}

public struct RunOutcome: Sendable {
    public let trace: Trace
    public let result: PropertyResult
}

public actor FailureStore {
    public func persist(_ artifact: FailureArtifact) async throws -> ReplayHandle {
        // File backend in v1, SQLite-backed implementation in v2.
    }
}
```

### Pattern 3: Storage-agnostic persistence facade
**What:** `ConjectureDatabase` owns the public persistence API and delegates to file or SQLite drivers internally.
**When:** From v1 onward.
**Why:** This keeps v2 SQLite additive instead of forcing a public API rename from “files” to “database”.

### Pattern 4: Explicit async isolation semantics
**What:** Public async APIs that are intended to inherit caller isolation should say so explicitly. Do not rely on implicit `nonisolated` behavior changing across toolchain settings.
**When:** Any public async API in adapters, persistence, telemetry, or future scheduler hooks.
**Why:** Swift 6.2 introduces `NonisolatedNonsendingByDefault`; relying on defaults creates subtle source and ABI traps that a greenfield framework does not need.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Letting adapters own engine behavior
**What:** `ConjectureTesting` or `ConjectureXCTest` starts implementing shrinking, replay, or trace decisions.
**Why bad:** It forks semantics by test framework and makes v2 parallelism or persistence refactors adapter-specific.
**Instead:** Keep adapters as presentation and integration shells over `ConjectureCore`.

### Anti-Pattern 2: Making strategy witnesses async or actor-bound
**What:** Witness closures require `await`, actors, or captured mutable reference state in the hot path.
**Why bad:** Parallel execution then forces `Sendable` retrofits, actor hops, or witness redesign.
**Instead:** Keep witnesses synchronous and `Sendable`; isolate external mutable state before it reaches the core.

### Anti-Pattern 3: Exposing SQLite in the public `ConjectureDatabase` API
**What:** Public APIs return SQL rows, connection handles, pragma knobs, or WAL policy types.
**Why bad:** v1 becomes storage-coupled and v2 is no longer additive.
**Instead:** Expose replay handles, failure queries, and storage-neutral records; keep SQLite types internal to `ConjectureSQLite`.

### Anti-Pattern 4: Multi-connection WAL design as the default
**What:** v2 opens multiple write-capable SQLite connections and checkpoints from arbitrary tasks.
**Why bad:** SQLite WAL still allows only one writer, long readers can starve checkpoints, and the official WAL docs now note a rare corruption bug fixed in `3.51.3` on 2026-03-13 for concurrent checkpoint/write races.
**Instead:** Use one actor-owned writable connection, short-lived reads, and controlled checkpoint policy. If Conjecture eventually needs multi-connection WAL behavior, pin or vendor a SQLite version that includes the fix.

### Anti-Pattern 5: Treating exported code coverage JSON as hot-path engine input
**What:** The core engine waits on coverage export or parses `llvm-cov` JSON while generating examples.
**Why bad:** Clang source-based coverage is compile -> run -> merge -> export. It is a post-run artifact, not a cheap in-process signal.
**Instead:** Keep coverage guidance in a sidecar module that imports artifacts after runs and influences future scheduling or seed ranking.

## Risks Where Package Boundaries Could Drift from the ARD

| Risk | Why It Happens | Guardrail |
|------|----------------|-----------|
| `ConjectureCore` starts importing I/O, paths, or SQL concerns | Persistence arrives after core APIs are already public | Freeze `ConjectureDatabase` early; reject filesystem and SQLite symbols in core review |
| `ConjectureStrategies` captures non-`Sendable` mutable reference state | Witness closures are ergonomic places to stash context | Require `Sendable` witness containers and parallel-worker tests before v1 API freeze |
| Adapters accumulate domain logic | Test-framework UX work often feels “small” and slips inward | Keep adapter target counts and public entry points intentionally small; shared fixtures test common behavior once |
| `ConjectureDatabase` leaks storage implementation details | SQLite is tempting to expose once it exists | Storage-neutral public protocols and DTOs only; keep SQL and checkpoint policy internal |
| v2 parallelism forces core API rewrites | Witnesses or run outcomes were not designed for task boundaries | Make core state, outcomes, and witnesses `Sendable` from the start |
| Coverage guidance demands engine hooks everywhere | The first implementation is often tool-driven rather than architecture-driven | Restrict coverage to an event import/snapshot seam owned by `ConjectureCoverage` |

## Scalability Considerations

| Concern | At 100 users | At 10K users | At 1M users |
|---------|--------------|--------------|-------------|
| Failure persistence volume | File-backed envelopes are acceptable | SQLite indexes and compaction matter | Sharding, archival, and migration tooling matter |
| Parallel property execution | Optional, modest worker counts | Stable `Sendable` witnesses and scheduler policy are required | Scheduler telemetry and backpressure become first-class |
| Coverage-guided exploration | Offline import is sufficient | Guidance snapshots should be cached per suite or workspace | Dedicated artifact pipeline and pruning policy are required |
| Public API stability | Easy to keep adapters thin | Storage-neutral APIs prevent churn | Any leaked backend detail becomes expensive to unwind |

## Sources

- [Swift PackageDescription API](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html) — HIGH
- [Swift 6 Concurrency Migration Guide: Enable data-race safety checking](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/enabledataracesafety/) — HIGH
- [Swift Evolution SE-0461: Run nonisolated async functions on the caller's actor by default](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md) — HIGH
- [Swift diagnostics: Sending value risks causing data races](https://github.com/swiftlang/swift/blob/main/userdocs/diagnostics/sending-risks-data-race.md) — HIGH
- [Swift diagnostics: Captures in a `@Sendable` closure](https://github.com/swiftlang/swift/blob/main/userdocs/diagnostics/sendable-closure-captures.md) — HIGH
- [SQLite: Using SQLite In Multi-Threaded Applications](https://www.sqlite.org/threadsafe.html) — HIGH
- [SQLite: Write-Ahead Logging](https://www.sqlite.org/wal.html) — HIGH
- [Clang Source-based Code Coverage](https://clang.llvm.org/docs/SourceBasedCodeCoverage.html) — HIGH
- Local toolchain evidence captured on 2026-03-30:
  - `swift --version` -> Apple Swift `6.2.4`
  - `swift build --help` and `swift test --help` -> current SwiftPM flags including `--explicit-target-dependency-import-check`, `--enable-code-coverage`, `--parallel`, and `--show-codecov-path`
  - `sqlite3 --version` -> `3.51.0`
  - `xcrun llvm-cov --version` and `xcrun llvm-profdata --version` -> Apple LLVM `17.0.0`
