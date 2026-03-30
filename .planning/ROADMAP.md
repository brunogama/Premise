# Roadmap: Conjecture

## Overview

Conjecture will be delivered as a SwiftPM-first, engine-driven property-testing
framework. The roadmap intentionally front-loads package boundaries, strict
concurrency, determinism, replay, and stable persistence before adapter polish
or v2 differentiators. That sequencing keeps the v1 core credible while making
SQLite, coverage guidance, parallel execution, telemetry, and SMT support truly
additive.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundations** - Freeze the package graph, strict-concurrency (completed 2026-03-30)
      contract, and core architectural boundaries.
- [x] **Phase 2: Deterministic Trace Engine** - Build the trace-first engine, (completed 2026-03-30)
      replay model, shrinker, and strategy catalog.
- [ ] **Phase 3: File Persistence and Versioning** - Add the v1 failure store
      with stable trace and failure-record formats.
- [ ] **Phase 4: Test Framework Adapters** - Ship thin `swift-testing` and
      XCTest integrations with contract coverage and diagnostics.
- [ ] **Phase 5: SQLite WAL Persistence** - Add the v2 SQLite backend behind
      the storage boundary with runtime gating and migration support.
- [ ] **Phase 6: Guided Execution and Extensions** - Add coverage guidance,
      parallel execution, telemetry, and optional SMT-backed providers.

## Phase Details

### Phase 1: Foundations
**Goal**: Establish a SwiftPM-first package with the correct target graph,
strict-concurrency rules, and non-negotiable architectural invariants before
engine APIs become sticky.
**Depends on**: Nothing (first phase)
**Requirements**: [CORE-04, CORE-05, PACK-01, PACK-02, PACK-03]
**Success Criteria** (what must be TRUE):
  1. The repository builds as a layered SwiftPM package with the expected v1
     products and explicit target dependencies.
  2. `ConjectureCore` compiles under Swift 6 strict concurrency without
     importing `swift-testing` or XCTest.
  3. The default build excludes v2-only capabilities while preserving clean
     extension seams for later phases.
  4. Boundary enforcement exists so adapters and storage cannot leak back into
     the core targets.
**Plans**: 3 plans

Plans:
- [x] 01-01: Create the SwiftPM manifest, v1 runtime targets, and smoke-test scaffold.
- [x] 01-02: Define strict-concurrency-safe core, strategy, database, and adapter boundary stubs.
- [x] 01-03: Add boundary enforcement, CI validation, and contributor guidance for the package contract.

### Phase 2: Deterministic Trace Engine
**Goal**: Deliver the engine-first choice-trace runtime, structural shrinking,
deterministic replay, and the first complete strategy catalog.
**Depends on**: Phase 1
**Requirements**: [CORE-01, CORE-02, CORE-03, STRA-01, STRA-02, STRA-03, STRA-04]
**Success Criteria** (what must be TRUE):
  1. Properties execute through a trace-first engine that records every
     generation decision required for replay.
  2. A stored trace deterministically reproduces the same failing example.
  3. Shrinking reduces failures structurally at the trace/span level for
     composed strategies.
  4. Standard strategies cover common Swift scalar, optional, and collection
     domains with deterministic edge-case-aware generation.
**Plans**: 4 plans

Plans:
- [x] 02-01: Implement the trace model, draw state, and deterministic providers.
- [x] 02-02: Add the core runner and replay-first execution contract.
- [x] 02-03: Build the standard strategy catalog and composition helpers.
- [x] 02-04: Implement structural shrinking and end-to-end minimization tests.

### Phase 3: File Persistence and Versioning
**Goal**: Add the v1 local example database and stable replay artifact formats
without coupling persistence to engine internals.
**Depends on**: Phase 2
**Requirements**: [PERS-01, PERS-02, PERS-03, PERS-04]
**Success Criteria** (what must be TRUE):
  1. Failing examples persist locally in a file-backed database with a public,
     versioned record format.
  2. Saved failures replay before fresh generation for the same property.
  3. Unsupported trace versions fail with explicit compatibility errors rather
     than silent misreads.
  4. The persistence boundary stays storage-neutral so SQLite can land later
     without changing replay semantics.
**Plans**: 3 plans

Plans:
- [ ] 03-01-PLAN.md — Define versioned persistence artifact contracts and compatibility validation.
- [ ] 03-02-PLAN.md — Implement the file-backed v1 database with atomic save/load/clear behavior.
- [ ] 03-03-PLAN.md — Wire replay-first execution through persistence and verify replay ordering.

### Phase 4: Test Framework Adapters
**Goal**: Ship thin adapters for `swift-testing` and XCTest that expose
Conjecture naturally inside standard Swift test runners.
**Depends on**: Phase 3
**Requirements**: [ADPT-01, ADPT-02, ADPT-03, ADPT-04, ADPT-05]
**Success Criteria** (what must be TRUE):
  1. Swift developers can author properties through `forAll` in
     `swift-testing` and `conjecture_forAll` in XCTest.
  2. Property authoring supports async/throws and per-property execution
     configuration under Swift 6 strict concurrency.
  3. Failure output includes the minimized counterexample, run/shrink counts,
     and replay instructions.
  4. Adapter contract tests prove the same replay and shrinking semantics
     across both test frameworks.
**Plans**: 4 plans

Plans:
- [ ] 04-01-PLAN.md — Define a shared async execution + diagnostics contract at the core-facing boundary.
- [ ] 04-02-PLAN.md — Implement thin `forAll` integration for `swift-testing` on top of the shared driver.
- [ ] 04-03-PLAN.md — Implement thin `conjecture_forAll` integration for XCTest on top of the shared driver.
- [ ] 04-04-PLAN.md — Add dedicated adapter parity/diagnostics tests and run full Phase 4 verification.

### Phase 5: SQLite WAL Persistence
**Goal**: Add the v2 SQLite-backed storage engine behind the existing
Conjecture database facade with explicit WAL policy and compatibility rules.
**Depends on**: Phase 4
**Requirements**: [SQLI-01, COMP-01]
**Success Criteria** (what must be TRUE):
  1. Users can switch to a SQLite WAL-backed failure store without changing the
     v1 property authoring APIs.
  2. SQLite-backed persistence preserves the same replay artifact contract and
     accepts v1-compatible records.
  3. SQLite runtime gating or distribution policy prevents unsupported WAL
     deployments on known-bad library versions.
**Plans**: 2 plans

Plans:
- [x] 05-01-PLAN.md — Build SQLite foundation: runtime gate, connection lifecycle, WAL pragmas, and schema DDL.
- [x] 05-02-PLAN.md — Implement SQLiteBackedDatabase actor with round-trip and v1 compatibility tests.

### Phase 6: Guided Execution and Extensions
**Goal**: Add opt-in differentiators on top of the stable v1 core: guided
exploration, parallel execution, telemetry, and solver-backed providers.
**Depends on**: Phase 5
**Requirements**: [COVR-01, PARA-01, TELE-01, SMT-01]
**Success Criteria** (what must be TRUE):
  1. Users can opt into coverage-guided exploration, parallel execution,
     telemetry hooks, and SMT-backed providers without changing the default
     build or public v1 APIs.
  2. Parallel execution preserves deterministic seed distribution and shared
     persistence semantics.
  3. Guided execution and telemetry remain additive sidecars rather than
     leaking instrumentation concerns into replay semantics.
  4. Optional extensions remain isolated as leaf modules with no back-edges
     into the v1 core.
**Plans**: 4 plans

Plans:
- [x] 06-01-PLAN.md -- Add trait-gated manifest and ConjectureTelemetry module with event protocol, sink, and relay.
- [ ] 06-02-PLAN.md -- Implement ConjectureParallel deterministic parallel execution.
- [ ] 06-03-PLAN.md -- Implement ConjectureCoverageGuided coverage signal ingestion.
- [x] 06-04-PLAN.md -- Implement ConjectureSMT solver-backed provider.

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundations | 3/3 | Complete   | 2026-03-30 |
| 2. Deterministic Trace Engine | 4/4 | Complete | 2026-03-30 |
| 3. File Persistence and Versioning | 0/TBD | Not started | - |
| 4. Test Framework Adapters | 0/TBD | Not started | - |
| 5. SQLite WAL Persistence | 1/2 | In Progress|  |
| 6. Guided Execution and Extensions | 1/4 | In Progress | - |
