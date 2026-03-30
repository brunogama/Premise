# Project Research Summary

**Project:** Premise
**Domain:** Swift-native property-based testing framework
**Researched:** 2026-03-30
**Confidence:** HIGH

## Executive Summary

Premise should be built as a SwiftPM-first property-based testing framework
with a deterministic trace engine at the center, thin `swift-testing` and
XCTest adapters at the edge, and persistence treated as a storage boundary
rather than part of the engine. The consistent pattern across
[STACK.md](./STACK.md), [FEATURES.md](./FEATURES.md),
[ARCHITECTURE.md](./ARCHITECTURE.md), and
[PITFALLS.md](./PITFALLS.md) is that experts do not start with fuzzing extras,
database backends, or DSL sprawl. They freeze the package graph, make replay
and shrinking deterministic, and only then add adapters and opt-in extensions.

The recommended v1 approach is narrow and opinionated: SwiftPM `6.1+`,
`swiftLanguageModes: [.v6]`, a synchronous and `Sendable` core, a composable
strategy layer, structural shrinking, trace-first replay, and a Foundation-only
file store with versioned failure records. That combination gives Premise the
minimum credible product: standard-runner integration, async/throws-safe Swift 6
authoring, minimized failures, and durable local replay.

The main risks are architectural drift and version-sensitive infrastructure.
If replay depends on ambient state, adapters leak into the core, or persistence
stores opaque internal blobs, later SQLite, coverage-guided execution, and
parallelism will force rewrites. There are also two concrete version caveats:
Swift 6.2 toolchains changed async isolation defaults enough that public async
APIs should be explicit about isolation semantics, and the locally observed
SQLite `3.51.0` is below the recommended `3.51.3+` WAL-reset fix, so any SQLite
phase must include runtime gating or a pinned distribution plan.

## Key Findings

### Recommended Stack

The stack recommendation is intentionally conservative. Keep the framework as a
pure Swift package, keep `PremiseCore` and `PremiseStrategies` free of
test frameworks and storage implementation details, and make all v2 capability
growth additive through leaf targets and package traits instead of widening the
core API.

See [STACK.md](./STACK.md) for the full stack matrix and package structure.

**Core technologies:**
- `SwiftPM 6.1+` with `swift-tools-version: 6.1` and package traits:
  package graph, optional add-ons, and additive feature growth.
- `Swift language mode .v6`: strict concurrency and `Sendable` checking are a
  design constraint, not a cleanup task.
- `Foundation`: v1 file persistence, JSON encoding, directory resolution, and
  stable local storage without third-party dependencies.
- `swift-testing` and XCTest adapters: standard test-runner integration without
  polluting core engine modules.
- `swift-docc-plugin 1.1.0`: official package-native docs workflow.

### Expected Features

The research is clear about the launch bar: Premise is not credible without
standard-runner adapters, async/throws-safe authoring, a serious strategy
library, automatic shrinking, deterministic replay, and local persistence that
replays saved failures before fresh generation. Those are table stakes for this
product definition, not stretch goals.

See [FEATURES.md](./FEATURES.md) for the full landscape and dependency graph.

**Must have (table stakes):**
- Thin `swift-testing` and XCTest adapters with trait-friendly configuration.
- Async/throws-safe Swift 6 authoring under strict concurrency.
- Composable strategies for standard Swift domains plus custom types.
- Edge-case-aware generation, automatic structural shrinking, and trace-first
  replay.
- Local file-backed failure persistence with replay-before-generate behavior.
- Actionable diagnostics and discard accounting.

**Should have (competitive):**
- Stable, versioned trace and failure-record formats.
- Structural shrinking that keeps working for composed custom strategies.
- Telemetry hooks and distribution introspection.

**Defer (v2+):**
- SQLite-backed persistence.
- Parallel property execution and corpus coordination.
- Coverage-guided execution.
- Optional SMT-backed providers.
- Stateful/model-based testing and remote corpus storage.

### Architecture Approach

Architecture research strongly favors one Swift package with a strict one-way
target graph. `PremiseCore` owns the engine state machine, typed trace,
replay cursor, shrinking, and provider contracts. `PremiseStrategies` owns
strategy builders and composition. `PremiseDatabase` owns versioned failure
envelopes, migrations, and the single actor that serializes file or SQLite I/O.
`PremiseTesting` and `PremiseXCTest` stay thin and translate framework
expectations into shared core behavior. All later features land as inward-facing
leaf targets, never as new back-edges into v1 modules.

See [ARCHITECTURE.md](./ARCHITECTURE.md) for the full target graph and data
flow.

**Major components:**
1. `PremiseCore` — deterministic engine, typed trace, replay, shrinking,
   provider contracts, and stable run outcomes.
2. `PremiseStrategies` — public strategy catalog, witness factories, and
   compositional generation helpers.
3. `PremiseDatabase` — storage-neutral persistence facade, versioned replay
   artifacts, and actor-owned file/SQLite backends.
4. `PremiseTesting` and `PremiseXCTest` — thin adapters for runner
   integration, diagnostics, and replay ergonomics.
5. v2 leaf modules (`PremiseSQLite`, `PremiseParallel`,
   `PremiseCoverage`, `PremiseTelemetry`, `PremiseSMT`) — optional
   capabilities built on stable v1 seams.

### Critical Pitfalls

The early roadmap must be organized to prevent the core rewrites described in
[PITFALLS.md](./PITFALLS.md). The top failure modes all come from doing later
integration work before the deterministic core is frozen.

1. **Ambient nondeterminism leaks into replay** — make the trace the sole
   authority for generation decisions; ban mutable globals in `PremiseCore`;
   prove serial replay invariance before any parallelism work.
2. **Shrinking edits realized values instead of the trace** — define shrinking
   as deterministic trace editing and lock in shrink invariance tests early.
3. **Failure persistence stores opaque internal blobs** — publish a versioned
   failure-record schema in v1 and keep stable replay artifacts separate from
   database internals.
4. **Core and adapter boundaries collapse** — keep runners framework-agnostic,
   enforce a one-way package graph, and use shared adapter contract tests.
5. **Strict concurrency is retrofitted late** — require `Sendable` witnesses,
   value-oriented core state, and complete concurrency checking from phase one.

## Implications for Roadmap

Based on the combined research, the roadmap should follow a six-phase shape.
This is the shortest path that preserves v1 determinism while keeping v2
features additive.

### Phase 1: Foundations
**Rationale:** Package boundaries and concurrency constraints must be frozen
before any engine or adapter API becomes sticky.
**Delivers:** SwiftPM target graph, `swift-tools-version: 6.1`, Swift 6 mode,
explicit target dependencies, import checks, and core invariants for
determinism and `Sendable` witnesses.
**Addresses:** Async/throws-safe authoring, thin-runner integration, additive
feature seams.
**Avoids:** Boundary collapse, late concurrency retrofits, and manifest choices
that leak experimental tooling into public products.

### Phase 2: Deterministic Trace Engine
**Rationale:** Replay and shrinking are the product. Everything else depends on
them.
**Delivers:** Typed trace model, replay cursor, deterministic engine loop,
provider contracts, composable standard strategies, edge-case scheduling, and a
golden shrink/replay corpus.
**Uses:** `PremiseCore` plus `PremiseStrategies` only.
**Avoids:** Ambient nondeterminism and value-level shrinking that cannot survive
strategy evolution.

### Phase 3: File Persistence and Format Versioning
**Rationale:** Local replay persistence is a v1 promise and must be storage
neutral before adapters get feature-rich.
**Delivers:** Versioned failure envelope, replay handle contract,
actor-owned Foundation file store, compatibility metadata, and forward/migration
tests.
**Implements:** `PremiseDatabase` as a storage-neutral facade.
**Avoids:** Opaque blob persistence and a v2 SQLite migration that changes the
public replay contract.

### Phase 4: Adapter Targets and Contract Tests
**Rationale:** Runner integration should arrive after the core semantics and
persistence model are already fixed.
**Delivers:** Thin `PremiseTesting` and `PremiseXCTest` products,
property-level configuration, diagnostics, attachments, discard accounting, and
shared adapter contract tests.
**Addresses:** Standard-runner adoption and actionable failure output.
**Avoids:** Framework-specific engine behavior and serial/parallel execution
divergence between adapters.

### Phase 5: SQLite WAL Persistence
**Rationale:** SQLite is infrastructure, not core value, so it should be a
storage leaf once the replay format is stable.
**Delivers:** `PremiseSQLite`, single-writer actor ownership, explicit WAL
and checkpoint policy, migration from file records, and runtime version gating.
**Uses:** Stable `PremiseDatabase` contracts and a patched SQLite baseline.
**Avoids:** `SQLITE_BUSY`, checkpoint starvation, WAL file growth, and the
2026-03-13 WAL-reset bug exposure.

### Phase 6: Coverage-Guided Execution, Parallelism, and Optional Extensions
**Rationale:** These are valuable differentiators, but only after single-run
determinism, persistence, and adapter behavior are proven.
**Delivers:** `PremiseParallel`, `PremiseCoverage`,
`PremiseTelemetry`, and optional `PremiseSMT` leaves with opt-in traits.
**Implements:** Guidance as sidecar feedback, isolated workers, telemetry hooks,
and solver-backed providers without changing v1 APIs.
**Avoids:** Coverage artifacts leaking into replay semantics, unsafe flags
polluting public products, and shared-state bugs under parallel execution.

### Phase Ordering Rationale

- The build order is dependency-driven: core semantics first, then storage,
  then adapters, then optional infrastructure-heavy extensions.
- Features are grouped by architectural seam: engine and strategies together,
  persistence behind one facade, adapters above the core, and v2 work in leaf
  modules only.
- The early phases directly neutralize the worst pitfalls: determinism,
  structural shrinking, stable replay format, and strict concurrency all need to
  exist before SQLite, coverage, or parallel scheduling can be safe.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 5:** SQLite WAL rollout needs implementation-level research on version
  pinning, runtime gating, checkpoint policy, and migration mechanics because
  the observed local SQLite version is `3.51.0`, below the recommended fix
  baseline.
- **Phase 6:** Coverage-guided execution needs toolchain-specific research
  because Swift/LLVM coverage is primarily a post-run artifact and some
  SanitizerCoverage modes remain experimental.
- **Phase 6:** SMT integration needs a separate solver comparison; the package
  boundary is clear, but the actual solver choice remains low-confidence.

Phases with standard patterns (skip research-phase):
- **Phase 1:** SwiftPM layering, strict concurrency, and explicit import checks
  are well documented by official Swift tooling.
- **Phase 3:** Foundation file persistence and versioned envelopes are standard,
  low-risk patterns.
- **Phase 4:** Thin adapter design for `swift-testing` and XCTest is
  straightforward once the shared runner contract exists.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Backed mostly by official SwiftPM, Foundation, Swift Testing, DocC, and SQLite sources. |
| Features | HIGH | Table stakes and differentiators were reinforced across mature PBT ecosystems and Swift-native expectations. |
| Architecture | HIGH | Layering, concurrency isolation, and storage boundaries are well supported; coverage-guidance mechanics are still medium-confidence. |
| Pitfalls | HIGH | Core risks are strongly evidenced by Swift concurrency, SQLite WAL, and replay guidance; shrinker architecture details still rely partly on design inference. |

**Overall confidence:** HIGH

### Gaps to Address

- **SQLite distribution strategy:** Decide whether Premise will require,
  vendor, or runtime-gate a SQLite build that includes the WAL-reset fix before
  Phase 5 starts.
- **SMT backend selection:** Run a focused comparison before planning the
  optional solver module.
- **Coverage feedback mechanism:** Validate the cheapest stable signal path for
  guidance so coverage stays a sidecar input instead of a hot-path dependency.
- **Swift toolchain support floor:** Confirm CI and consumer support for
  SwiftPM `6.1+` traits while keeping async isolation semantics explicit for
  Swift 6.2-era toolchains.

## Sources

### Primary (HIGH confidence)
- Swift Package Manager `Package`, `Target`, `Trait`, and language-mode docs —
  package graph, traits, and toolchain floor.
- Swift Testing official docs and repository — runner behavior, traits, and
  async/parallel expectations.
- Apple Foundation docs (`JSONEncoder`, `Data.write`, `FileManager.url`) —
  v1 persistence APIs.
- Swift concurrency migration and diagnostics docs — strict concurrency,
  `Sendable`, and async isolation requirements.
- SQLite WAL and locking docs — WAL policy, single-writer constraints, and the
  2026-03-13 WAL-reset fix details.
- Clang and LLVM coverage docs — post-run coverage workflow and experimental
  instrumentation caveats.

### Secondary (MEDIUM confidence)
- Hypothesis, jqwik, Proptest, SwiftCheck, and PropertyBased for Swift —
  feature expectations, replay patterns, shrinking norms, and anti-features.
- GRDB and SQLite.swift docs — alternatives considered for future storage layers.

---
*Research completed: 2026-03-30*
*Ready for roadmap: yes*
