# Requirements: Conjecture

**Defined:** 2026-03-30
**Core Value:** Swift developers can write property tests that automatically produce minimal, replayable failures while the core engine stays fast, deterministic, and strict-concurrency-safe.

## v1 Requirements

### Core Engine

- [x] **CORE-01**: Test authors can run properties through an engine-first
      choice-trace model that records every generation decision needed for
      replay and shrinking.
- [ ] **CORE-02**: A failing property can be replayed deterministically from a
      recorded trace and reproduce the same counterexample.
- [ ] **CORE-03**: A failing property is shrunk structurally at the trace/span
      level until Conjecture finds a smaller still-failing counterexample or
      reaches the configured shrink limit.
- [ ] **CORE-04**: `ConjectureCore` compiles under Swift 6 strict concurrency
      without importing `swift-testing` or XCTest.
- [ ] **CORE-05**: Strategy and provider execution in the hot path preserves
      protocol-witness dispatch rather than existential storage.

### Strategies

- [ ] **STRA-01**: Test authors can generate bounded integers, booleans,
      floating-point values, bytes, strings, optionals, and collections using
      built-in strategies.
- [ ] **STRA-02**: Test authors can compose strategies with `map`, `flatMap`,
      `filter`, `oneOf`, `frequency`, and recursive composition helpers.
- [ ] **STRA-03**: Built-in strategies include deterministic edge-case-aware
      generation for boundaries such as zero, empty values, and range limits.
- [ ] **STRA-04**: Test authors can define custom strategy witnesses without
      coupling custom generators to adapter-specific APIs.

### Persistence And Replay

- [x] **PERS-01**: Conjecture persists failing examples locally through a
      file-backed database in v1.
- [x] **PERS-02**: Conjecture replays persisted failures for a property before
      generating fresh examples for that property.
- [x] **PERS-03**: Failure artifacts use an explicit, versioned trace and
      failure-record format that can be validated on load.
- [x] **PERS-04**: Conjecture rejects unsupported future trace versions
      explicitly instead of silently misreading them.

### Adapters And Authoring

- [x] **ADPT-01**: Swift developers can author properties through a
      `swift-testing` adapter using `forAll`.
- [x] **ADPT-02**: Swift developers can author properties through an XCTest
      adapter using `conjecture_forAll`.
- [x] **ADPT-03**: Property authors can configure per-property execution knobs
      such as run count, shrink limit, draw budget, replay behavior, and seed.
- [x] **ADPT-04**: Failure output includes the minimal example, run/shrink
      counts, and replay instructions.
- [x] **ADPT-05**: Property authoring works naturally with async/throws test
      code under Swift 6 strict concurrency.

### Package And Delivery

- [ ] **PACK-01**: Consumers can adopt Conjecture as layered SwiftPM products:
      `ConjectureCore`, `ConjectureStrategies`, `ConjectureDatabase`,
      `ConjectureTesting`, and `ConjectureXCTest`.
- [ ] **PACK-02**: The package enforces a one-way target dependency graph so
      core, strategy, persistence, and adapter layers do not leak back into
      each other.
- [ ] **PACK-03**: The package can be built and tested through `swift build`
      and `swift test` with warnings treated as errors.

## v2 Requirements

### Storage And Execution

- **SQLI-01**: Users can switch to a SQLite WAL-backed failure store without
  changing the v1 property authoring APIs.
- **PARA-01**: Users can run properties in parallel with deterministic seed
  distribution and a single shared persistence contract.
- [x] **COVR-01**: Users can opt into coverage-guided exploration through an
  additive extension target that does not affect the default build.
- [x] **TELE-01**: Users can attach telemetry hooks to observe run, replay, and
  shrink events without changing core engine semantics.
- **SMT-01**: Users can opt into an SMT-backed provider as an extension target
  rather than a mandatory dependency.
- **COMP-01**: V2 remains backward-compatible with v1 replay artifacts and
  public APIs while rejecting incompatible newer trace formats when loaded by
  older engines.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Remote or network-backed failure storage | The product scope keeps persistence local in v1 and local/SQLite in v2. |
| Hosted service or SaaS features | Conjecture is a package and local test-time tool, not an online platform. |
| Stateful/model-based testing DSL in v1 | It would expand the surface area before the single-property engine, replay, and shrinking contracts are proven. |
| Bespoke assertion language | Swift developers already have `#expect`, `#require`, and XCTest assertions. |
| Huge domain-specific generator packs in the initial release | A strong core strategies layer and extension points matter more than early breadth. |
| Default-on coverage instrumentation | SanitizerCoverage remains an additive, toolchain-sensitive v2 capability. |
| Remote corpus sharing or collaborative databases | That adds auth, sync, and privacy concerns outside the current product scope. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CORE-01 | Phase 2 | Complete |
| CORE-02 | Phase 2 | Pending |
| CORE-03 | Phase 2 | Pending |
| CORE-04 | Phase 1 | Pending |
| CORE-05 | Phase 1 | Pending |
| STRA-01 | Phase 2 | Pending |
| STRA-02 | Phase 2 | Pending |
| STRA-03 | Phase 2 | Pending |
| STRA-04 | Phase 2 | Pending |
| PERS-01 | Phase 3 | Complete |
| PERS-02 | Phase 3 | Complete |
| PERS-03 | Phase 3 | Complete |
| PERS-04 | Phase 3 | Complete |
| ADPT-01 | Phase 4 | Complete |
| ADPT-02 | Phase 4 | Complete |
| ADPT-03 | Phase 4 | Complete |
| ADPT-04 | Phase 4 | Complete |
| ADPT-05 | Phase 4 | Complete |
| PACK-01 | Phase 1 | Pending |
| PACK-02 | Phase 1 | Pending |
| PACK-03 | Phase 1 | Pending |
| SQLI-01 | Phase 5 | Complete |
| PARA-01 | Phase 6 | Pending |
| COVR-01 | Phase 6 | Complete |
| TELE-01 | Phase 6 | Complete |
| SMT-01 | Phase 6 | Complete |
| COMP-01 | Phase 5 | Complete |

**Coverage:**
- v1 requirements: 21 total
- Mapped to phases: 21
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-30*
*Last updated: 2026-03-30 after initial definition*
