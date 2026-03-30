# Phase 06: Guided Execution and Extensions - Research

**Researched:** 2026-03-30  
**Domain:** Swift 6 additive extension architecture for guided exploration, deterministic parallel execution, telemetry, and optional SMT providers  
**Confidence:** MEDIUM-HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

No `06-CONTEXT.md` exists in `.planning/phases/06-guided-execution-and-extensions`.

### Locked Decisions
- None provided in a phase-local CONTEXT artifact.

### Claude's Discretion
- All implementation choices not already fixed by `.planning/ROADMAP.md` and `.planning/REQUIREMENTS.md`.

### Deferred Ideas (OUT OF SCOPE)
- None provided in a phase-local CONTEXT artifact.
</user_constraints>

## Project Constraints (from CLAUDE.md)

- `CLAUDE.md` requires following `AGENTS.md`.
- `RULES.md` quality gates are mandatory: formatter/lint/build/tests (warnings-as-errors), no bypasses.
- Keep `ConjectureCore` and `ConjectureStrategies` free of `Testing`/`XCTest` imports (enforced by `scripts/validate-boundaries.sh`).
- Preserve clean layering and additive v2 modules; do not back-edge v2 concerns into v1 core.
- Use `rg` for repository searches; prefer project wrapper tooling for web/doc research when available.
- Release/tag workflow is out of scope unless explicitly requested by the user.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PARA-01 | Users can run properties in parallel with deterministic seed distribution and a single shared persistence contract. | Use `withThrowingTaskGroup`, but map each logical run index to a deterministic seed independent of completion order; keep persistence fan-in through the existing `ExampleDatabase` actor. |
| COVR-01 | Users can opt into coverage-guided exploration through an additive extension target that does not affect the default build. | Use SwiftPM traits (`@available(_PackageDescription, introduced: 6.1)`) and conditional target/build settings; keep coverage instrumentation and scoring in a leaf target (`ConjectureCoverageGuided`). |
| TELE-01 | Users can attach telemetry hooks to observe run, replay, and shrink events without changing core engine semantics. | Implement sidecar telemetry sinks/adapters in extension targets; avoid global logging initialization; emit observational events only (no replay-affecting state). |
| SMT-01 | Users can opt into an SMT-backed provider as an extension target rather than a mandatory dependency. | Add trait-gated SMT leaf target + `systemLibrary` target (`pkgConfig: "z3"`), isolate solver contexts, and enforce Z3 ref-count/threading rules. |
</phase_requirements>

## Summary

Phase 06 should be implemented as **leaf extension modules + SwiftPM traits**, not by widening the v1 core API. The core already has stable deterministic seams (`Runner`, `PropertyConfig.seed`, `ExampleDatabase` actor). Build on those seams with additive targets: `ConjectureParallel`, `ConjectureCoverageGuided`, `ConjectureTelemetry`, and `ConjectureSMT`.

The critical technical risk is nondeterminism leakage. Swift task groups return results in completion order, not submission order, so parallel execution must normalize results back to logical run index order before any persistence/replay decisions. Coverage and telemetry must stay sidecars: they can observe and rank, but must not mutate trace semantics or failure-record contracts.

SMT integration is feasible as an optional target, but only if treated as infrastructure: system library boundary, explicit version policy, and strict Z3 lifetime/threading discipline. The local environment has Z3 installed (`4.15.4`) and `pkg-config` available, so implementation can proceed now with runtime/CI version gating.

**Primary recommendation:** Implement Phase 06 as trait-gated extension targets with deterministic logical-index scheduling and actor-owned sidecar services; keep `ChoiceTrace` and replay artifacts instrumentation-free.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftPM Traits + Conditions (`Trait`, `TargetDependencyCondition.when(traits:)`, `BuildSettingCondition.when(..., traits:)`) | PackageDescription 6.1 APIs | Additive opt-in feature gates for coverage/telemetry/SMT | Officially supports additive feature modeling and trait-conditional dependencies/settings. |
| Swift Structured Concurrency (`withThrowingTaskGroup`) | Swift 6.x | Parallel run scheduling | Official structured concurrency model with clear completion/cancellation guarantees. |
| `ConjectureCore` (`Runner`, `PseudoRandomProvider`, `ChoiceTrace`) | in-repo | Deterministic run/replay semantics | Existing seed and trace model is the invariant base for parallel/guided extensions. |
| `ConjectureDatabase` (`ExampleDatabase` actor) | in-repo | Shared persistence contract | Actor boundary already exists for safe shared state across concurrent workers. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `apple/swift-log` (`Logging`) | `1.10.0` (2026-02-16) | Structured telemetry backend adapter | Telemetry extension target (`ConjectureTelemetryLogging`) only; keep core independent. |
| `apple/swift-distributed-tracing` (`Tracing`, `Instrumentation`) | `1.4.1` (2026-03-10) | Trace/span correlation for telemetry hooks | When exporting Conjecture events into tracing systems. |
| `apple/swift-atomics` (`Atomics`) | `1.3.0` (2025-06-04) | Low-overhead counters/flags | High-throughput telemetry/counter aggregation when actor-only is too hot. |
| LLVM SanitizerCoverage (`-sanitize-coverage=...`) | Toolchain feature (`swiftc`/`clang`) | Coverage signal extraction for guidance | Coverage-guided extension only; not in default build path. |
| Z3 C API + system package (`z3`) | Latest upstream `z3-4.16.0` (2026-02-19); local `4.15.4` | SMT-backed provider | `ConjectureSMT` trait only; gate by availability/version policy. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SwiftPM traits for feature gating | Custom env flags / ad-hoc `#if` knobs | Traits are first-class and additive; custom flags drift and are harder for users/CI to reason about. |
| Leaf telemetry adapters | Core-integrated logging API changes | Sidecars preserve v1 API/replay semantics; core integration risks semantic leakage. |
| Deterministic logical-index seeding | Worker-thread-local system RNG | Thread-local RNG is easy but breaks reproducibility across worker counts/schedules. |
| `systemLibrary` Z3 boundary | Mandatory bundled solver dependency | Optional leaf target keeps default build lightweight and avoids forcing solver runtime on all consumers. |

**Installation:**

```bash
# Optional extension dependencies
swift package add-dependency https://github.com/apple/swift-log.git --from 1.10.0
swift package add-dependency https://github.com/apple/swift-distributed-tracing.git --from 1.4.1
swift package add-dependency https://github.com/apple/swift-atomics.git --from 1.3.0

# Optional SMT runtime (macOS/Homebrew)
brew install z3

# Build with opt-in traits
swift build --traits CoverageGuided,Telemetry,SMT
```

**Version verification (executed 2026-03-30):**
- `swift-log`: `1.10.1` latest (2026-02-16), but `1.10.0` is recommended here to preserve Swift tools 6.1 compatibility.
- `swift-atomics`: `1.3.0` (2025-06-04).
- `swift-distributed-tracing`: `1.4.1` (2026-03-10).
- `z3`: `z3-4.16.0` latest upstream (2026-02-19); local machine currently has `4.15.4`.

## Architecture Patterns

### Recommended Project Structure

```text
Sources/
├── ConjectureCore/                    # unchanged v1 deterministic engine
├── ConjectureDatabase/                # shared persistence actor contract
├── ConjectureParallel/                # opt-in scheduler and deterministic shard mapping
├── ConjectureCoverageGuided/          # opt-in coverage signal ingestion + scoring
├── ConjectureTelemetry/               # opt-in event protocol + sinks
├── ConjectureTelemetryLogging/        # swift-log/tracing adapter target
├── ConjectureSMT/                     # opt-in solver-backed provider
└── CZ3/                               # systemLibrary target for z3 C API

Tests/
├── ConjectureCoreTests/
├── ConjectureDatabaseTests/
├── ConjectureParallelTests/
├── ConjectureCoverageGuidedTests/
├── ConjectureTelemetryTests/
└── ConjectureSMTTests/
```

### Pattern 1: Trait-Gated Additive Leaves

**What:** Use SwiftPM traits to keep extension modules additive and off by default.  
**When to use:** For all Phase 06 capabilities (coverage, telemetry, SMT, optional parallel behavior toggles).  
**Example:**

```swift
// Source: swift-package-manager Trait.swift + Target.swift (PackageDescription 6.1)
let package = Package(
  // ...
  traits: [
    .trait(name: "CoverageGuided"),
    .trait(name: "Telemetry"),
    .trait(name: "SMT"),
    .default(enabledTraits: [])
  ],
  targets: [
    .target(
      name: "ConjectureSMT",
      dependencies: [
        "ConjectureCore",
        .target(name: "CZ3", condition: .when(traits: ["SMT"]))
      ]
    ),
    .systemLibrary(
      name: "CZ3",
      pkgConfig: "z3",
      providers: [.brew(["z3"]), .apt(["z3"])]
    ),
  ]
)
```

### Pattern 2: Logical-Index Parallel Scheduling

**What:** Seed by logical run index, not worker identity; reorder task-group completions by index.  
**When to use:** `PARA-01` implementation and any future parallel run fan-out.  
**Example:**

```swift
// Source: SE-0304 (TaskGroup next() completion-order), local Runner seed model
let baseSeed = config.seed ?? 0
var ordered = Array<RunResult<Value>?>(repeating: nil, count: config.maxRuns)

try await withThrowingTaskGroup(of: (Int, RunResult<Value>).self) { group in
  for runIndex in 0..<config.maxRuns {
    let seedForIndex = splitMix64(baseSeed &+ UInt64(runIndex))
    group.addTask {
      let result = await runSingle(seed: seedForIndex, runIndex: runIndex)
      return (runIndex, result)
    }
  }

  while let (runIndex, result) = try await group.next() {
    ordered[runIndex] = result
  }
}
```

### Pattern 3: Sidecar Telemetry and Guidance

**What:** Emit observational events from extension targets; never mutate replay trace/failure records with instrumentation-only fields.  
**When to use:** Telemetry hooks (`TELE-01`) and guidance score updates (`COVR-01`).  
**Example:**

```swift
public enum EngineEvent: Sendable {
  case runStarted(propertyID: PropertyIdentity, runIndex: Int)
  case replayAttempt(propertyID: PropertyIdentity, traceHash: UInt64)
  case shrinkStep(propertyID: PropertyIdentity, iteration: Int)
  case runFinished(propertyID: PropertyIdentity, passed: Bool)
}

public protocol TelemetrySink: Sendable {
  func record(_ event: EngineEvent) async
}
```

### Pattern 4: Solver Context Isolation + Ref Management

**What:** Wrap Z3 context/solver lifetimes explicitly; keep solver objects per worker/task and manage refs deterministically.  
**When to use:** `ConjectureSMT` provider implementation.  
**Example:**

```c
// Source: Z3 C API docs (group__capi)
Z3_context ctx = Z3_mk_context(cfg);
Z3_solver solver = Z3_mk_solver(ctx);
Z3_solver_inc_ref(ctx, solver);
// ... assert/check/model ...
Z3_solver_dec_ref(ctx, solver);
Z3_del_context(ctx);
```

### Anti-Patterns to Avoid

- **Completion-order semantics leak:** relying on `group.next()` order for deterministic run identity.
- **Global RNG in parallel hot path:** using `SystemRandomNumberGenerator` directly for reproducible property exploration.
- **Unsafe instrumentation flags in public products:** `unsafeFlags` on distributable targets can make products ineligible as package dependencies.
- **Library-level `LoggingSystem.bootstrap` calls:** bootstrap can only be called once per process.
- **Coverage data in replay artifacts:** adding instrumentation-derived fields to `ChoiceTrace`/failure records breaks stable replay semantics.
- **Shared unsynchronized Z3 state:** cross-task solver/context sharing without explicit isolation and reference management.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Feature-gating system | Custom env/CLI feature flags parser | SwiftPM traits + conditional dependency/build-setting APIs | Native package semantics, additive guarantees, and toolchain support. |
| Parallel result ordering | Ad-hoc “first finished wins” logic | Task-group fan-out + index-normalized fan-in | Completion order is nondeterministic by design; index normalization restores determinism. |
| Telemetry backend | Custom global logger singleton and print pipelines | `swift-log` `LogHandler` adapters + optional `swift-distributed-tracing` | Proven ecosystem APIs; avoids hard-coding one observability sink. |
| Atomic synchronization primitives | Lock-heavy bespoke counters | `Atomics.ManagedAtomic` or actor-isolated aggregation | Better correctness/perf tradeoff and less concurrency bug surface. |
| Coverage signal plumbing | Custom binary formats/parsers from scratch | LLVM SanitizerCoverage callbacks/options + standard toolchain outputs | Officially documented instrumentation points and formats. |
| Solver FFI lifetime policy | Scattered raw pointer/ref handling in business logic | Thin RAII-style wrapper over Z3 C API refs (`inc_ref`/`dec_ref`) | Prevents leaks/use-after-free and centralizes thread-safety policy. |

**Key insight:** Phase 06 succeeds if extensions compose around stable core seams; hand-rolled infrastructure in core is the main source of semantic drift.

## Common Pitfalls

### Pitfall 1: Completion-Order Nondeterminism
**What goes wrong:** Parallel runs produce different failure ordering between executions.  
**Why it happens:** `TaskGroup.next()` yields completion order, not submission order.  
**How to avoid:** Persist and evaluate by logical run index; reorder completions before deciding replay/persistence outcomes.  
**Warning signs:** Same seed + inputs produce different first-failure run indices when worker count changes.

### Pitfall 2: Reproducibility Broken by RNG Choice
**What goes wrong:** Parallel mode cannot reproduce failures across machine/core-count changes.  
**Why it happens:** System RNG is thread-safe and cryptographically strong, but not designed for deterministic replay sequences.  
**How to avoid:** Keep deterministic seed derivation (`baseSeed + runIndex` + stable mixing), and use explicit seedable RNG streams per logical run.  
**Warning signs:** Re-run with recorded seed fails to recreate counterexample under different worker counts.

### Pitfall 3: Unsafe Flag Spillover
**What goes wrong:** Package consumers fail dependency resolution/build policy checks.  
**Why it happens:** SwiftPM marks products containing `unsafeFlags` targets as ineligible for use by other packages.  
**How to avoid:** Isolate instrumentation-only flags to opt-in leaf targets and keep default/public v1 products clean.  
**Warning signs:** Consumer package cannot depend on Conjecture products after adding coverage instrumentation flags.

### Pitfall 4: Logging Bootstrap Collisions
**What goes wrong:** Runtime crashes or undefined behavior when telemetry module initializes logging.  
**Why it happens:** `LoggingSystem.bootstrap` is one-time process-global.  
**How to avoid:** Never bootstrap inside library initialization paths; expose sink adapters and let app/test harness own bootstrap.  
**Warning signs:** Repeated test runs or multi-package integration crashes around logger setup.

### Pitfall 5: Instrumentation Leaks Into Replay Contract
**What goes wrong:** Replays depend on telemetry timestamps or coverage artifacts.  
**Why it happens:** Instrumentation fields are written into persistent failure/trace records.  
**How to avoid:** Keep replay artifacts strictly semantic (`ChoiceTrace` + deterministic failure fields), store telemetry/coverage in separate sidecar records.  
**Warning signs:** Replay passes/fails change when telemetry level or coverage flags change.

### Pitfall 6: Z3 Lifetime/Threading Bugs
**What goes wrong:** Intermittent crashes, leaks, or invalid models under parallel SMT use.  
**Why it happens:** Missing `inc_ref`/`dec_ref` management and/or shared contexts across tasks without safety controls.  
**How to avoid:** Use isolated solver contexts per task/worker, central wrappers, and explicit reference policy.  
**Warning signs:** Non-deterministic solver crashes in CI under parallel load.

### Pitfall 7: SQLite Runtime Drift Undermines Shared Persistence
**What goes wrong:** Rare WAL corruption risk remains in parallel persistence setups.  
**Why it happens:** Runtime SQLite version is below fixed WAL-reset versions.  
**How to avoid:** Keep Phase 5 runtime gating active; require `3.51.3+` (or documented backports) for WAL-backed parallel writes.  
**Warning signs:** Local environment reports `sqlite3 3.51.0` while WAL mode is enabled.

## Code Examples

Verified patterns from official sources and current codebase:

### 1) Trait-Gated Dependency + Build Condition

```swift
// Source: swift-package-manager BuildSettings.swift + Target.swift (6.1 APIs)
.target(
  name: "ConjectureCoverageGuided",
  dependencies: [
    "ConjectureCore",
    .product(name: "Logging", package: "swift-log", condition: .when(traits: ["Telemetry"]))
  ],
  swiftSettings: [
    .define("CONJECTURE_COVERAGE_GUIDED", .when(traits: ["CoverageGuided"]))
  ]
)
```

### 2) TaskGroup Ordering Guardrail

```swift
// Source: SE-0304 structured concurrency proposal
group.addTask { 1 }
group.addTask { 2 }
print(await group.next()) // may print 1 OR 2 (completion order)
```

### 3) Deterministic Seeded RNG Boundary

```swift
// Source: swift stdlib Random.swift comments + local PseudoRandomProvider style
public protocol RandomNumberGenerator {
  mutating func next() -> UInt64
}

// custom seedable RNG for deterministic tests/replay
var rng = SplitMix64(seed: stableSeed)
```

### 4) Safe Logging Integration Boundary

```swift
// Source: swift-log Logging.swift
// Do NOT call LoggingSystem.bootstrap in library init paths.
let logger = Logger(label: "conjecture.telemetry")
logger.info("run finished", metadata: ["property": "\(propertyID)"])
```

### 5) Z3 System Library Target

```swift
// Source: swift-package-manager Target.systemLibrary docs
.systemLibrary(
  name: "CZ3",
  pkgConfig: "z3",
  providers: [.brew(["z3"]), .apt(["z3"])]
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Ad-hoc feature flags for optional capabilities | SwiftPM package traits + trait-conditional dependencies/settings | PackageDescription 6.1 | Clean additive extension model with explicit CLI enablement (`--traits`). |
| Implicit reliance on worker scheduling order | Logical-index deterministic scheduling + completion-order normalization | Structured concurrency guidance (SE-0304) | Stable replay semantics across worker-count and timing differences. |
| Global logging init inside libraries | Process-owned bootstrap + library sink adapters | Swift-log current guidance | Avoids global init collisions and keeps telemetry pluggable. |
| Mandatory solver coupling in core | Optional solver leaf target via `systemLibrary` + trait gating | Mature SwiftPM system library + traits | Default build stays lightweight and API-stable; SMT remains opt-in. |

**Deprecated/outdated:**
- Treating coverage guidance as a default-on core behavior.
- Assuming thread-safe system RNG implies deterministic replay semantics.
- Embedding unsafe instrumentation flags in default/public library products.

## Open Questions

1. **Seed mixing contract for parallel logical runs**
   - What we know: deterministic per-run seed mapping is required; current core already uses seed+run index.
   - What's unclear: whether to standardize on SplitMix64-derived mapping as a documented compatibility contract.
   - Recommendation: freeze a named mapping function in `ConjectureParallel` and regression-test it as a compatibility surface.

2. **Coverage signal ingestion strategy**
   - What we know: `swiftc`/`clang` support sanitizer coverage instrumentation; unsafe flags can impact package-consumer eligibility.
   - What's unclear: whether Phase 06 should use callback-based signals, sancov file ingestion, or both.
   - Recommendation: start with callback-based in-process signals in trait-gated targets; defer offline corpus tooling to follow-up phase.

3. **SMT runtime/version policy**
   - What we know: upstream Z3 latest is `4.16.0`, local environment has `4.15.4`.
   - What's unclear: minimum supported Z3 version for ConjectureSMT CI matrix and user docs.
   - Recommendation: declare minimum tested version explicitly and fail-fast when unavailable/out-of-policy.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Swift toolchain (`swift`) | All Phase 06 implementation/tests | ✓ | 6.2.4 | — |
| SwiftLint (`swiftlint`) | RULES.md quality gates | ✓ | 0.63.2 | `/opt/homebrew/bin/swiftlint` |
| Clang/Swift sanitizer coverage flags | `ConjectureCoverageGuided` | ✓ | Apple clang 17.0.0 / `swiftc` supports `-sanitize-coverage` | Skip coverage trait if unavailable |
| Z3 CLI/library + pkg-config | `ConjectureSMT` | ✓ | Z3 4.15.4 (`pkg-config z3`) | Disable `SMT` trait |
| SQLite runtime | Shared persistence assumptions (Phase 5 dependency) | ✓ | 3.51.0 | Keep WAL runtime gating from Phase 5 |

**Missing dependencies with no fallback:**
- None.

**Missing dependencies with fallback:**
- Latest Z3 (`4.16.0`) not installed locally; fallback is keep SMT trait optional/disabled until version policy is met.
- SQLite is below `3.51.3` WAL-reset fix baseline; fallback is enforce existing runtime gate/backport policy from Phase 5.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | SwiftPM tests (Swift Testing + XCTest integration targets) |
| Config file | `Package.swift`, `.github/workflows/ci.yml`, `.swiftlint.yml` |
| Quick run command | `swift test --filter \"(ParallelDeterminismTests|CoverageGuidanceIsolationTests|TelemetryHookSemanticsTests|SMTProviderOptInTests)\"` |
| Full suite command | `bash scripts/validate-boundaries.sh && swift build --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors && swift test --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PARA-01 | Parallel execution preserves deterministic seed distribution and shared persistence semantics | integration | `swift test --filter ParallelDeterminismTests` | ❌ Wave 0 |
| COVR-01 | Coverage-guided path is opt-in extension and default build unchanged | unit/integration | `swift test --filter CoverageGuidanceIsolationTests` | ❌ Wave 0 |
| TELE-01 | Telemetry observes run/replay/shrink events without changing outcomes | unit/integration | `swift test --filter TelemetryHookSemanticsTests` | ❌ Wave 0 |
| SMT-01 | SMT provider is opt-in and absent from default dependency path | unit/integration | `swift test --filter SMTProviderOptInTests` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `swift test --filter \"(ParallelDeterminismTests|CoverageGuidanceIsolationTests|TelemetryHookSemanticsTests|SMTProviderOptInTests)\"`
- **Per wave merge:** `bash scripts/validate-boundaries.sh && /opt/homebrew/bin/swiftlint lint --strict --config .swiftlint.yml && swift build --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors && swift test --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors`
- **Phase gate:** Full suite green before `$gsd-verify-work`

### Wave 0 Gaps

- [ ] `Tests/ConjectureParallelTests/ParallelDeterminismTests.swift` — deterministic seed-to-run-index mapping and completion-order normalization for `PARA-01`.
- [ ] `Tests/ConjectureCoverageGuidedTests/CoverageGuidanceIsolationTests.swift` — trait-off default behavior and trait-on guidance behavior for `COVR-01`.
- [ ] `Tests/ConjectureTelemetryTests/TelemetryHookSemanticsTests.swift` — event emission without replay semantic drift for `TELE-01`.
- [ ] `Tests/ConjectureSMTTests/SMTProviderOptInTests.swift` — optional target wiring and runtime availability gating for `SMT-01`.
- [ ] `Package.swift` updates for new extension test targets and trait wiring.

## Sources

### Primary (HIGH confidence)

- Local project artifacts:
  - `.planning/ROADMAP.md` (Phase 06 goal/requirements)
  - `.planning/REQUIREMENTS.md` (`PARA-01`, `COVR-01`, `TELE-01`, `SMT-01`)
  - `Sources/ConjectureCore/Runner.swift` (current seed + run model)
  - `Sources/ConjectureCore/PseudoRandomProvider.swift` (current deterministic PRNG)
  - `Sources/ConjectureDatabase/ExampleDatabase.swift` (shared actor persistence seam)
- Swift structured concurrency proposal (SE-0304):  
  https://github.com/swiftlang/swift-evolution/blob/main/proposals/0304-structured-concurrency.md
- Swift stdlib RNG docs/comments (`Random.swift`):  
  https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Random.swift
- SwiftPM PackageDescription APIs:
  - Traits (`Trait.swift`): https://github.com/swiftlang/swift-package-manager/blob/main/Sources/Runtimes/PackageDescription/Trait.swift
  - Target dependency conditions (`Target.swift`): https://github.com/swiftlang/swift-package-manager/blob/main/Sources/Runtimes/PackageDescription/Target.swift
  - Build settings and unsafe flags (`BuildSettings.swift`): https://github.com/swiftlang/swift-package-manager/blob/main/Sources/Runtimes/PackageDescription/BuildSettings.swift
- SwiftPM CLI traits support (`swift package --help`) and sanitizer options (`swiftc --help`, `swift build --help`) collected locally on 2026-03-30.
- Swift-log bootstrap semantics (`Logging.swift`):  
  https://github.com/apple/swift-log/blob/main/Sources/Logging/Logging.swift
- LLVM/Clang coverage-guidance docs:
  - SanitizerCoverage: https://clang.llvm.org/docs/SanitizerCoverage.html
  - libFuzzer: https://llvm.org/docs/LibFuzzer.html
- Z3 C API docs:
  - API reference: https://z3prover.github.io/api/html/group__capi.html
  - Releases: https://github.com/Z3Prover/z3/releases
- SQLite WAL-reset fix and version notes:
  - https://sqlite.org/changes.html
  - https://sqlite.org/wal.html#walresetbug
- Release/version verification (GitHub API):
  - https://github.com/apple/swift-log/releases
  - https://github.com/apple/swift-atomics/releases
  - https://github.com/apple/swift-distributed-tracing/releases
  - https://github.com/Z3Prover/z3/releases

### Secondary (MEDIUM confidence)

- Rust Rand Book parallel RNG guidance (deterministic vs non-deterministic worker seeding):  
  https://rust-random.github.io/book/guide-parallel.html
- Existing in-repo broad architecture research (`.planning/research/*.md`) used as contextual alignment, cross-checked against primary sources.

### Tertiary (LOW confidence)

- Swift forum discussions used only as supporting context, not normative authority:
  - https://forums.swift.org/t/are-swifts-random-number-generators-able-to-work-concurrently/33801
  - https://forums.swift.org/t/deterministic-randomness-in-swift/20835
- CLI wrapper infrastructure for Exa/Ref/Firecrawl was partially unavailable in this environment (quota/endpoint/package errors), so official-source fallback was used.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - package/tooling decisions are backed by official SwiftPM/Swift/LLVM/Z3 docs and current release metadata.
- Architecture: MEDIUM-HIGH - deterministic scheduling and sidecar isolation are strongly supported, but final telemetry/coverage ingestion API shape remains discretionary.
- Pitfalls: HIGH - each pitfall maps to documented behavior (TaskGroup ordering, unsafe flags, bootstrap semantics, WAL fix notes, Z3 ref model).

**Research date:** 2026-03-30  
**Valid until:** 2026-04-29
