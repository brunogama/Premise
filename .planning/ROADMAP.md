# Roadmap: Premise

## Overview

Premise will be delivered as a SwiftPM-first, engine-driven property-testing
framework. The roadmap intentionally front-loads package boundaries, strict
concurrency, determinism, replay, and stable persistence before adapter polish
or v2 differentiators. That sequencing keeps the v1 core credible while making
SQLite, coverage guidance, parallel execution, telemetry, and SMT support truly
additive.

## Milestones

- [x] **v1.0 MVP** - Phases 1-6 (shipped 2026-03-30)
- [ ] **v1.1 ARD Conformance + Documentation** - Phases 7-10 (in progress)

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

<details>
<summary>v1.0 MVP (Phases 1-6) - SHIPPED 2026-03-30</summary>

- [x] **Phase 1: Foundations** - Freeze the package graph, strict-concurrency
      contract, and core architectural boundaries.
- [x] **Phase 2: Deterministic Trace Engine** - Build the trace-first engine,
      replay model, shrinker, and strategy catalog.
- [x] **Phase 3: File Persistence and Versioning** - Add the v1 failure store
      with stable trace and failure-record formats.
- [x] **Phase 4: Test Framework Adapters** - Ship thin `swift-testing` and
      XCTest integrations with contract coverage and diagnostics.
- [x] **Phase 5: SQLite WAL Persistence** - Add the v2 SQLite backend behind
      the storage boundary with runtime gating and migration support.
- [x] **Phase 6: Guided Execution and Extensions** - Add coverage guidance,
      parallel execution, telemetry, and optional SMT-backed providers.

</details>

### v1.1 ARD Conformance + Documentation

- [ ] **Phase 7: ARD Trace Format and Engine Alignment** - Align the engine
      with the ARD spec: binary CBOR traces, SplitMix64 PRNG, fixed-capacity
      SpanStack, RunResult distinction, and debug assertions.
- [ ] **Phase 8: Coverage Integration** - Wire LLVM SanitizerCoverage into the
      coverage-guided provider with a graceful fallback path.
- [ ] **Phase 9: Tooling and Telemetry** - Ship CLI replay plugin, JSON-Lines
      output, import-restricting build plugin, and config-injected telemetry.
- [ ] **Phase 10: Developer Documentation** - Complete Documentation.docc
      catalog, tutorials, guides, and README rewrite.

## Phase Details

<details>
<summary>v1.0 Phase Details (Phases 1-6)</summary>

### Phase 1: Foundations
**Goal**: Establish a SwiftPM-first package with the correct target graph,
strict-concurrency rules, and non-negotiable architectural invariants before
engine APIs become sticky.
**Depends on**: Nothing (first phase)
**Requirements**: CORE-04, CORE-05, PACK-01, PACK-02, PACK-03
**Success Criteria** (what must be TRUE):
  1. The repository builds as a layered SwiftPM package with the expected v1
     products and explicit target dependencies.
  2. `PremiseCore` compiles under Swift 6 strict concurrency without
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
**Requirements**: CORE-01, CORE-02, CORE-03, STRA-01, STRA-02, STRA-03, STRA-04
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
**Requirements**: PERS-01, PERS-02, PERS-03, PERS-04
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
- [x] 03-01: Define versioned persistence artifact contracts and compatibility validation.
- [x] 03-02: Implement the file-backed v1 database with atomic save/load/clear behavior.
- [x] 03-03: Wire replay-first execution through persistence and verify replay ordering.

### Phase 4: Test Framework Adapters
**Goal**: Ship thin adapters for `swift-testing` and XCTest that expose
Premise naturally inside standard Swift test runners.
**Depends on**: Phase 3
**Requirements**: ADPT-01, ADPT-02, ADPT-03, ADPT-04, ADPT-05
**Success Criteria** (what must be TRUE):
  1. Swift developers can author properties through `forAll` in
     `swift-testing` and `premise_forAll` in XCTest.
  2. Property authoring supports async/throws and per-property execution
     configuration under Swift 6 strict concurrency.
  3. Failure output includes the minimized counterexample, run/shrink counts,
     and replay instructions.
  4. Adapter contract tests prove the same replay and shrinking semantics
     across both test frameworks.
**Plans**: 4 plans

Plans:
- [x] 04-01: Define a shared async execution + diagnostics contract at the core-facing boundary.
- [x] 04-02: Implement thin `forAll` integration for `swift-testing` on top of the shared driver.
- [x] 04-03: Implement thin `premise_forAll` integration for XCTest on top of the shared driver.
- [x] 04-04: Add dedicated adapter parity/diagnostics tests and run full Phase 4 verification.

### Phase 5: SQLite WAL Persistence
**Goal**: Add the v2 SQLite-backed storage engine behind the existing
Premise database facade with explicit WAL policy and compatibility rules.
**Depends on**: Phase 4
**Requirements**: SQLI-01, COMP-01
**Success Criteria** (what must be TRUE):
  1. Users can switch to a SQLite WAL-backed failure store without changing the
     v1 property authoring APIs.
  2. SQLite-backed persistence preserves the same replay artifact contract and
     accepts v1-compatible records.
  3. SQLite runtime gating or distribution policy prevents unsupported WAL
     deployments on known-bad library versions.
**Plans**: 2 plans

Plans:
- [x] 05-01: Build SQLite foundation: runtime gate, connection lifecycle, WAL pragmas, and schema DDL.
- [x] 05-02: Implement SQLiteBackedDatabase actor with round-trip and v1 compatibility tests.

### Phase 6: Guided Execution and Extensions
**Goal**: Add opt-in differentiators on top of the stable v1 core: guided
exploration, parallel execution, telemetry, and solver-backed providers.
**Depends on**: Phase 5
**Requirements**: COVR-01, PARA-01, TELE-01, SMT-01
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
- [x] 06-01: Update Package.swift with trait-gated extension targets and implement telemetry hooks.
- [x] 06-02: Implement deterministic parallel execution with logical-index seed mapping.
- [x] 06-03: Implement coverage-guided exploration as trait-gated additive leaf.
- [x] 06-04: Implement SMT-backed provider with Z3 lifetime management and version policy.

</details>

### Phase 7: ARD Trace Format and Engine Alignment
**Goal**: The engine internals match the Architecture Reference Document
specification for trace serialization, PRNG, span management, run-result
classification, and debug-build safety checks.
**Depends on**: Phase 6
**Requirements**: TRAC-01, TRAC-02, TRAC-03, ENGI-01, ENGI-02, ENGI-03, ENGI-04
**Success Criteria** (what must be TRUE):
  1. Traces serialize and deserialize through a compact binary CBOR format with
     the 4-byte magic header and 2-byte version field defined in the ARD.
  2. The engine rejects traces carrying unsupported version bytes with a typed
     `TraceError.unsupportedVersion` error.
  3. Existing v1.0 JSON-encoded traces can be converted to the binary format
     through an explicit migration API.
  4. The PRNG produces the exact SplitMix64 sequence (multiply/XOR-shift) for
     a given seed, matching the ARD reference vectors.
  5. The span stack uses a fixed-capacity tuple with zero heap allocation, and
     debug builds run SpanValidator assertions plus round-trip serialization
     checks after every draw.
**Plans**: TBD

Plans:
- [ ] 07-01: TBD
- [ ] 07-02: TBD

### Phase 8: Coverage Integration
**Goal**: The coverage-guided provider reads real LLVM SanitizerCoverage edge
data at runtime and degrades gracefully when instrumentation is absent.
**Depends on**: Phase 7
**Requirements**: COVR-02, COVR-03
**Success Criteria** (what must be TRUE):
  1. The coverage-guided provider integrates with LLVM SanitizerCoverage
     through a C shim that reads `__sanitizer_cov_pcs_init` edge data and
     feeds it into the coverage bitmap.
  2. When SanitizerCoverage instrumentation is not available, the provider
     falls back to standard PRNG-driven generation without crashing or
     producing diagnostics that confuse the user.
**Plans**: TBD

Plans:
- [ ] 08-01: TBD

### Phase 9: Tooling and Telemetry
**Goal**: Developers can replay traces from the CLI, consume structured output
in CI, enforce module boundaries automatically, and inject telemetry without
extra imports.
**Depends on**: Phase 7
**Requirements**: TOOL-01, TOOL-02, TOOL-03, TELM-02
**Success Criteria** (what must be TRUE):
  1. A developer can run `swift package conjreplay <trace-path>` to replay a
     stored trace and see the reproduced failure without writing a test file.
  2. The runner can emit structured JSON-Lines output that a CI pipeline parses
     alongside the default human-readable format.
  3. A build plugin fails the build when restricted imports (e.g.,
     `swift-testing` inside `PremiseCore`) appear in the wrong target.
  4. Telemetry events emit through `PropertyConfig.telemetry` without requiring
     a separate module import in the property test.
**Plans**: TBD

Plans:
- [ ] 09-01: TBD
- [ ] 09-02: TBD

### Phase 10: Developer Documentation
**Goal**: A new user can go from zero to a passing property test with full API
reference, authoring guides, and migration path documentation.
**Depends on**: Phase 9
**Requirements**: DOCS-01, DOCS-02, DOCS-03, DOCS-04, DOCS-05
**Success Criteria** (what must be TRUE):
  1. A Documentation.docc catalog builds and renders structured API reference
     for all public types across all Premise modules.
  2. A getting-started tutorial walks a new user from adding the package
     dependency to a first passing property test.
  3. A strategy authoring guide explains how to build custom `Strategy<A>`
     witnesses with composition, shrinking, and spans.
  4. A migration guide explains the v1 file-backed to v2 SQLite upgrade path
     and the JSON-to-CBOR trace format evolution.
  5. The README includes real examples, feature overview, installation
     instructions, and links into the DocC articles.
**Plans**: TBD

Plans:
- [ ] 10-01: TBD
- [ ] 10-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 7 -> 8 -> 9 -> 10

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundations | v1.0 | 3/3 | Complete | 2026-03-30 |
| 2. Deterministic Trace Engine | v1.0 | 4/4 | Complete | 2026-03-30 |
| 3. File Persistence and Versioning | v1.0 | 3/3 | Complete | 2026-03-30 |
| 4. Test Framework Adapters | v1.0 | 4/4 | Complete | 2026-03-30 |
| 5. SQLite WAL Persistence | v1.0 | 2/2 | Complete | 2026-03-30 |
| 6. Guided Execution and Extensions | v1.0 | 4/4 | Complete | 2026-03-30 |
| 7. ARD Trace Format and Engine Alignment | v1.1 | 0/TBD | Not started | - |
| 8. Coverage Integration | v1.1 | 0/TBD | Not started | - |
| 9. Tooling and Telemetry | v1.1 | 0/TBD | Not started | - |
| 10. Developer Documentation | v1.1 | 0/TBD | Not started | - |
