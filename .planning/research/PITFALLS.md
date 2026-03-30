# Domain Pitfalls

**Domain:** Swift-native property-based testing engine
**Project:** Conjecture
**Researched:** 2026-03-30
**Overall confidence:** HIGH for concurrency, packaging, SQLite WAL, and
coverage-guided execution; MEDIUM for shrinker architecture guidance where the
evidence is an inference from replay and flakiness constraints rather than a
single upstream rule.

## Roadmap Prevention Phases

Use these phase names in roadmap planning so the pitfalls are prevented before
they turn into rewrite work:

1. **Phase 1: Foundations**
   Package graph, strict-concurrency contract, target boundaries, and engine
   invariants.
2. **Phase 2: Deterministic Trace Engine**
   Choice trace model, replay contract, and shrinking invariants.
3. **Phase 3: File Persistence And Format Versioning**
   File-backed failure storage and stable trace schema.
4. **Phase 4: Adapter Targets And Contract Tests**
   `swift-testing` and XCTest integration without polluting the core.
5. **Phase 5: SQLite WAL Persistence**
   Optional database-backed storage with explicit checkpoint policy.
6. **Phase 6: Coverage-Guided Execution And Parallelism**
   Instrumentation, corpus feedback, and parallel property execution.

## Critical Pitfalls

### Pitfall 1: Ambient Nondeterminism Leaks Into Generation Or Replay
**Confidence:** HIGH

**What goes wrong:** Conjecture records a failure, but replay is flaky because
some generation or execution decision came from wall clock time, shared mutable
state, filesystem state, task scheduling, or adapter-controlled hooks instead of
the recorded trace.

**Why it happens:** Property engines often start by treating randomness and test
execution as "ambient" concerns. That works until replay, shrinking, parallel
execution, and persisted failures all depend on those same decisions being made
again.

**Consequences:** Replay breaks, shrinking becomes unreliable, coverage feedback
gets noisy, and failures found under CI stop reproducing locally.

**Warning signs:**
- The same persisted failure sometimes passes on replay.
- The same seed or stored trace produces different draw counts or different
  shrink paths.
- Core code needs mutable globals, singleton registries, or `sleep()` to make
  tests pass.
- Swift 6 emits `@Sendable` capture or global shared mutable state diagnostics
  in engine code.

**Prevention strategy:**
- Treat the choice trace as the only authoritative source of generation
  decisions.
- Keep randomness, coverage signals, and adapter metadata outside the public
  replay format unless they are explicitly recorded.
- Make serial replay pass before any parallel execution work starts.
- Add replay-invariance tests: same trace, same property, same failure, same
  shrink frontier.
- Ban mutable global engine state in `ConjectureCore`.

**Phase to address it:** Phase 1 and Phase 2.

### Pitfall 2: Shrinking Operates On Realized Values Instead Of The Trace
**Confidence:** MEDIUM

**What goes wrong:** Shrinking edits materialized values after generation
instead of editing the structural choice trace. That causes invalid intermediate
states, strategy-specific escape hatches, or shrinks that no longer replay once
strategy internals evolve.

**Why it happens:** Value-level shrinking feels simpler at first, but it hides
which choices were actually made during generation. Once strategies become
composed or stateful, value-level shrinkers no longer preserve generator
invariants.

**Consequences:** Shrinks are slow, unstable, and hard to reason about.
Minimized failures can silently depend on current generator implementation
details instead of the recorded failure.

**Warning signs:**
- New strategy types require custom shrink logic almost everywhere.
- A "minimal" failure changes when the strategy implementation changes but the
  persisted failure does not.
- Shrink steps frequently produce values that the original generator would never
  emit.
- Replay depends on hidden generator bookkeeping instead of only the recorded
  trace.

**Prevention strategy:**
- Make shrinking an edit operation over a typed trace, not over arbitrary
  user-facing values.
- Define invariants early: replay must be trace-driven, shrink steps must be
  replayable, and shrink ordering must be deterministic.
- Create a golden shrink corpus in Phase 2 and keep it stable across refactors.
- Separate "provider choices" from "realized strategy values" in the engine API.

**Phase to address it:** Phase 2.

### Pitfall 3: Failure Persistence Uses Opaque Internal Blobs Instead Of A Stable, Versioned Format
**Confidence:** HIGH

**What goes wrong:** Stored failures only replay on the same commit or the same
internal engine layout. A later trace refactor, file-to-SQLite migration, or
toolchain upgrade invalidates old failures.

**Why it happens:** Internal state serialization is fast to ship, but internal
formats drift. Hypothesis explicitly warns that its local database can be
invalidated by upgrades and that `@reproduce_failure` blobs are not stable
across versions.

**Consequences:** Users lose the main value proposition of persistent replay.
V2 migration becomes a data-migration problem instead of an additive feature.

**Warning signs:**
- Replay only works when run from the exact same checkout or toolchain.
- The design treats SQLite row layout or raw JSON encoding as the public replay
  contract.
- Upgrade notes tell users to delete old failure data.
- CI and local machines cannot share failures reliably.

**Prevention strategy:**
- Define a public failure record schema in v1 with an explicit format version.
- Keep the stable replay format separate from internal caches and database
  tables.
- Persist enough metadata to validate compatibility: trace format version,
  strategy/provider version, toolchain version, and checksum.
- Write forward-compatibility tests before Phase 3 is considered complete.
- When SQLite arrives, migrate file records into SQLite rather than replacing
  the public record model.

**Phase to address it:** Phase 2 and Phase 3.

### Pitfall 4: Core And Adapter Boundaries Collapse
**Confidence:** HIGH

**What goes wrong:** `ConjectureCore` starts importing `Testing`, XCTest, or
adapter-specific lifecycle concepts. The core then inherits framework-specific
execution rules, and adapters stop being thin.

**Why it happens:** It is tempting to bootstrap with one runner first and "pull
the core up later." That usually fails once adapter semantics diverge.
`swift-testing` runs tests in parallel by default, while the Swift 5.10
`XCTestScaffold` shim was explicitly left serial.

**Consequences:** Core APIs become unstable, replay semantics differ by runner,
and strict-concurrency work gets tangled with test-framework behavior.

**Warning signs:**
- Public core APIs mention `Testing`, XCTest, traits, or assertion types.
- Adapter code owns engine decisions instead of only translating framework
  events.
- The same property behaves differently under `swift-testing` and XCTest.
- Package targets require back-edges from core into adapters.

**Prevention strategy:**
- Keep `ConjectureCore` runner and trace logic framework-agnostic.
- Restrict adapters to translation concerns: naming, failure surfacing, runner
  lifecycle, and optional framework metadata.
- Enforce a one-way package graph in `Package.swift`.
- Add shared adapter contract tests so both adapters must satisfy the same
  replay and shrinking behavior.
- If adapter-specific execution traits are added, keep their ordering and scope
  outside the core engine.

**Phase to address it:** Phase 1 and Phase 4.

### Pitfall 5: Strict Concurrency Is Retrofitted After The Public API Exists
**Confidence:** HIGH

**What goes wrong:** The engine works in an early prototype, but Swift 6
complete concurrency checking later exposes non-`Sendable` providers,
nonisolated shared mutable state, and `@Sendable` closure capture problems
throughout the API.

**Why it happens:** Libraries often defer concurrency rules until they add
parallelism. In Swift 6, that is too late because public API shape,
capturability, and shared state choices all affect concurrency checking.

**Consequences:** Late actorization, lock retrofits in the hot path, or public
API breakage to add `Sendable` and isolation constraints.

**Warning signs:**
- Compiler errors about captured `var` values in concurrently executing code.
- Diagnostics about non-`Sendable` captures or global shared mutable state.
- Core types require `nonisolated(unsafe)` to compile.
- `@MainActor` or UI-style isolation leaks into engine and persistence code.

**Prevention strategy:**
- Compile every new target with complete concurrency checking from the start.
- Prefer `struct`-based witnesses and immutable trace data in the core.
- Move shared mutable state behind explicit actor or locked boundaries in
  non-hot modules only.
- Keep provider and strategy abstractions honest about `Sendable` requirements.
- Treat `nonisolated(unsafe)` as a last-resort exception with a written reason,
  not a default escape hatch.

**Phase to address it:** Phase 1.

### Pitfall 6: SQLite WAL Is Treated As Passive Storage Instead Of An Operational Subsystem
**Confidence:** HIGH

**What goes wrong:** V2 persistence assumes WAL mode is automatically "better,"
then runs into `SQLITE_BUSY`, large `-wal` files, checkpoint starvation,
surprising copy/move semantics, or rare but real concurrency bugs.

**Why it happens:** WAL improves read/write overlap, but SQLite still allows only
one writer at a time, checkpointing remains an application concern, WAL requires
local shared memory, and long-running readers can block checkpoint completion.
Also, SQLite disclosed the WAL-reset bug on 2026-03-13: it affected versions
3.7.0 through 3.51.2 and was fixed in 3.51.3, with backports 3.44.6 and
3.50.7.

**Consequences:** Slow or stuck persistence, nondeterministic test failures,
corrupted expectations about durability, and migration pain when users copy
databases without companion WAL files.

**Warning signs:**
- `*.wal` files grow without shrinking.
- Multiple connections write or checkpoint concurrently.
- Long-lived read transactions remain open during test runs.
- Databases live on network filesystems or synchronized folders.
- Failure reports mention `SQLITE_BUSY` or intermittent checkpoint stalls.

**Prevention strategy:**
- Keep v1 persistence file-backed and simple; do not introduce SQLite before the
  replay format is stable.
- In v2, use a single-writer actor or queue for database mutation.
- Pin a minimum SQLite version that includes the 2026-03-13 WAL-reset fix.
- Design an explicit checkpoint policy and test long-reader scenarios.
- Keep databases local-only and copy/move them only with SQLite closed or with
  all companion files preserved.

**Phase to address it:** Phase 5.

### Pitfall 7: Coverage-Guided Execution Is Coupled To Unstable Compiler Instrumentation Or Public Products
**Confidence:** HIGH

**What goes wrong:** Coverage guidance depends directly on raw guard IDs, PC
tables, or toolchain-specific counters. Toolchain upgrades churn the corpus,
instrumentation overhead dominates runtime, or the package becomes unusable as a
dependency because `unsafeFlags` leak into shipped targets.

**Why it happens:** LLVM SanitizerCoverage exposes useful instrumentation, but
some modes are explicitly experimental and may change or disappear. SwiftPM also
marks products using `unsafeFlags` as ineligible for use by other packages.

**Consequences:** V2 coverage guidance becomes brittle, expensive, and hard to
ship cleanly. Consumers pay for experimental tooling choices they did not opt
into.

**Warning signs:**
- Coverage IDs change across compiler versions or build modes.
- Adapter code and test scaffolding dominate "new coverage" events.
- The public package manifest needs `unsafeFlags` for normal consumption.
- Coverage artifacts are being persisted as if they were stable replay inputs.

**Prevention strategy:**
- Keep coverage guidance opt-in and isolated to an internal harness or internal
  target.
- Treat raw instrumentation output as ephemeral feedback, not as public replay
  data.
- Allowlist only the engine code that should drive guidance.
- Convert compiler events into stable internal heuristics before they affect
  corpus retention.
- Do not expose unsafe build settings through public library products.

**Phase to address it:** Phase 6.

## Moderate Pitfalls

### Pitfall 8: Parallel Execution Arrives Before Per-Run Isolation And Teardown Contracts
**Confidence:** HIGH

**What goes wrong:** Property runs leak tasks, temp files, database handles, or
shared caches across iterations. This may look harmless in serial mode and then
collapse under `swift-testing`'s default parallel execution or Conjecture's own
future parallel runner.

**Warning signs:**
- Tests only pass with `swift test --no-parallel`.
- Background tasks or threads outlive one property run.
- A rerun passes because previous state was cleaned up accidentally.

**Prevention strategy:**
- Define a per-run execution context object with explicit setup and teardown.
- Namespace temp directories, persistence records, and telemetry by property run.
- Require all tasks and threads to finish before a run completes.
- Keep parallel execution out of the roadmap until serial determinism tests are
  green.

**Phase to address it:** Phase 4 and Phase 6.

### Pitfall 9: Package Manifest Choices Leak Experimental Tooling Into The Consumer Surface
**Confidence:** HIGH

**What goes wrong:** The package manifest mixes public products with experimental
coverage, snapshot-only compiler features, or adapter-only dependencies. That
raises the support floor for every consumer.

**Warning signs:**
- Consumers need a development snapshot just to use `ConjectureCore`.
- Public library targets require instrumentation or adapter dependencies.
- The manifest uses `unsafeFlags` in targets that are part of library products.

**Prevention strategy:**
- Keep experimental tooling in internal targets or separate products.
- Give public products the narrowest dependency graph possible.
- Make the minimum supported toolchain explicit and keep experimental features
  additive, not foundational.

**Phase to address it:** Phase 1.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Phase 1: Foundations | Core imports adapter code or relies on mutable globals | Lock the target graph early and compile with complete concurrency checking |
| Phase 2: Deterministic Trace Engine | Shrinker edits values instead of trace choices | Ship replay and shrink invariance tests before adding many strategies |
| Phase 3: File Persistence | Failure records are serialized as raw engine state | Define a stable schema with format version and compatibility tests |
| Phase 4: Adapters | `swift-testing` and XCTest diverge in execution behavior | Use adapter contract tests and keep framework semantics out of core |
| Phase 5: SQLite WAL Persistence | WAL files grow, checkpoint stalls, or concurrent writes race | Use single-writer ownership, explicit checkpoints, and a patched SQLite version |
| Phase 6: Coverage-Guided Execution And Parallelism | Coverage IDs and parallel state leak into replay semantics | Keep instrumentation ephemeral and parallelism above a deterministic serial core |

## Sources

- [HIGH] Swift diagnostics: `@Sendable` closure captures
  https://github.com/swiftlang/swift/blob/main/userdocs/diagnostics/sendable-closure-captures.md?plain=1#L1#captures-in-a-sendable-closure
- [HIGH] Swift diagnostics: unsafe mutable global and static variables
  https://github.com/swiftlang/swift/blob/main/userdocs/diagnostics/mutable-global-variable.md?plain=1#L1#unsafe-mutable-global-and-static-variables
- [HIGH] Swift Package Manager `PackageDescription` API, especially targets,
  products, and `unsafeFlags`
  https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html
- [HIGH] Swift Testing README: tests integrate with Swift Concurrency and run in
  parallel by default
  https://github.com/swiftlang/swift-testing
- [HIGH] `swift-testing` PR #174: `swift test` parallelization enabled by
  default, `--no-parallel` support, XCTest scaffold remains serial
  https://github.com/apple/swift-testing/pull/174
- [HIGH] `swift-testing` PR #733: traits can customize execution behavior and
  ordering must be explicit
  https://github.com/swiftlang/swift-testing/pull/733
- [HIGH] SQLite WAL documentation: concurrency, checkpointing, persistence of
  WAL mode, WAL file handling, and the WAL-reset bug fixed on 2026-03-13
  https://sqlite.org/wal.html
- [HIGH] SQLite locking and concurrency reference
  https://sqlite.org/lockingv3.html
- [HIGH] LLVM libFuzzer documentation: in-process execution, determinism,
  joining threads, avoiding global state, and corpus semantics
  https://llvm.org/docs/LibFuzzer.html
- [HIGH] LLVM SanitizerCoverage documentation: experimental instrumentation
  modes, PC tables, allowlists/blocklists, and coverage artifact format
  https://releases.llvm.org/19.1.0/tools/clang/docs/SanitizerCoverage.html
- [HIGH] Hypothesis docs: flaky failures and deterministic draw sequences
  https://hypothesis.readthedocs.io/en/latest/tutorial/flaky.html
- [HIGH] Hypothesis docs: replay database behavior, explicit examples, and
  version-unstable reproduce blobs
  https://hypothesis.readthedocs.io/en/latest/tutorial/replaying-failures.html

## Most Important Roadmap Implication

Do not let Conjecture's roadmap treat persistence, adapters, coverage guidance,
or parallelism as "later integrations" on top of a generic property runner.
The early phases must first lock down:

1. package boundaries and strict concurrency,
2. a deterministic trace model,
3. replayable structural shrinking, and
4. a stable persisted failure format.

If those four are not complete before SQLite WAL, coverage guidance, or parallel
execution begin, Conjecture is likely to rewrite its core abstractions instead
of adding v2 features cleanly.
