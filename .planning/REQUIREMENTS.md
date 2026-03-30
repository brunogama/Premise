# Requirements: Premise v1.1

**Defined:** 2026-03-30
**Core Value:** Swift developers can write property tests that automatically produce minimal, replayable failures while the core engine stays fast, deterministic, and strict-concurrency-safe.

## v1.1 Requirements

### Trace Format

- [ ] **TRAC-01**: The engine persists and replays traces using a compact binary
      CBOR format with a 4-byte magic header and 2-byte version field per the ARD
      specification.
- [ ] **TRAC-02**: The engine rejects traces with unsupported version bytes by
      throwing a typed `TraceError.unsupportedVersion` error rather than
      silently misreading.
- [ ] **TRAC-03**: V1.0 JSON-encoded traces can be migrated to the binary format
      through an explicit conversion path.

### Engine Internals

- [ ] **ENGI-01**: The PRNG uses the SplitMix64 algorithm with the exact
      multiply/XOR-shift sequence specified in the ARD.
- [ ] **ENGI-02**: The span stack uses a fixed-capacity tuple (zero heap
      allocation) rather than an array, matching the ARD's SpanStack design.
- [ ] **ENGI-03**: RunResult distinguishes between `.newFailure` (first discovery)
      and `.knownFailure` (replay of persisted trace) so adapters can report
      them differently.
- [ ] **ENGI-04**: Debug builds include a SpanValidator that asserts balanced
      span push/pop after every draw, plus round-trip trace serialization
      verification.

### Coverage Integration

- [ ] **COVR-02**: The coverage-guided provider integrates with LLVM
      SanitizerCoverage via a C shim that reads `__sanitizer_cov_pcs_init` edge
      data at runtime.
- [ ] **COVR-03**: The coverage-guided provider falls back to standard PRNG when
      SanitizerCoverage instrumentation is not available.

### Tooling

- [ ] **TOOL-01**: A `ConjReplay` SwiftPM command plugin allows replaying a
      stored trace from the command line without writing a test.
- [ ] **TOOL-02**: The runner supports structured JSON-Lines output mode for CI
      pipeline consumption alongside the default human-readable format.
- [ ] **TOOL-03**: A build plugin fails the build if restricted imports (e.g.,
      `swift-testing` in `PremiseCore`) appear in the wrong target.

### Telemetry

- [ ] **TELM-02**: Telemetry can be injected via `PropertyConfig.telemetry` so
      the runner emits events without requiring a separate module import.

### Documentation

- [ ] **DOCS-01**: A Documentation.docc catalog provides structured API reference
      for all public types across all modules.
- [ ] **DOCS-02**: A getting-started tutorial walks a new user from package
      dependency to first passing property test.
- [ ] **DOCS-03**: A strategy authoring guide explains how to build custom
      `Strategy<A>` witnesses with composition, shrinking, and spans.
- [ ] **DOCS-04**: A migration guide explains the v1 file-backed to v2 SQLite
      upgrade path and trace format evolution.
- [ ] **DOCS-05**: The README is rewritten with real examples, feature overview,
      installation instructions, and links to DocC articles.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Remote trace storage or sync | Local-first architecture; plugin concern for future milestone |
| Stateful/model-based testing DSL | Engine and strategy contracts must stabilize first |
| Performance benchmarking suite | Important but separate milestone concern |
| Xcode source editor integration | Requires Xcode plugin infrastructure outside package scope |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TRAC-01 | Phase 7 | Pending |
| TRAC-02 | Phase 7 | Pending |
| TRAC-03 | Phase 7 | Pending |
| ENGI-01 | Phase 7 | Pending |
| ENGI-02 | Phase 7 | Pending |
| ENGI-03 | Phase 7 | Pending |
| ENGI-04 | Phase 7 | Pending |
| COVR-02 | Phase 8 | Pending |
| COVR-03 | Phase 8 | Pending |
| TOOL-01 | Phase 9 | Pending |
| TOOL-02 | Phase 9 | Pending |
| TOOL-03 | Phase 9 | Pending |
| TELM-02 | Phase 9 | Pending |
| DOCS-01 | Phase 10 | Pending |
| DOCS-02 | Phase 10 | Pending |
| DOCS-03 | Phase 10 | Pending |
| DOCS-04 | Phase 10 | Pending |
| DOCS-05 | Phase 10 | Pending |

**Coverage:**
- v1.1 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0

---
*Requirements defined: 2026-03-30*
*Last updated: 2026-03-30 after roadmap creation*
