# Hypothesis Feature Parity Gap Plan

**Date:** 2026-06-10  
**Project:** Swift Premise  
**Goal:** Bring Premise closer to feature parity with Python Hypothesis while preserving Premise's Swift-native, macro-optional, storage-neutral architecture.

## Scan Summary

Scanned:

- `Package.swift`
- `Sources/`
- `Tests/`
- `README.md`
- `CHANGELOG.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `docs/superpowers/plans/2026-06-04-hypothesis-parity-foundation.md`

Also compared against current Python Hypothesis public feature areas: `@given`, `@example`, settings, phases, health checks, database/replay, observability, strategies, stateful testing, ghostwriter, external fuzzer bridge, and CLI/plugin tooling.

## Current Parity Already Present

Premise already has a strong foundation:

- Core runner, replay traces, and structural shrinking:
  - `Sources/PremiseCore/Runner.swift`
  - `Sources/PremiseCore/ChoiceTrace.swift`
  - `Sources/PremiseCore/ShrinkMachine.swift`
- File and SQLite persistence:
  - `Sources/PremiseDatabase/`
- swift-testing and XCTest adapters:
  - `Sources/PremiseTesting/ForAll.swift`
  - `Sources/PremiseXCTest/PremiseForAll.swift`
- Optional `@given` macro:
  - `Sources/PremiseMacrosPlugin/GivenMacro.swift`
- Basic phases:
  - `.explicit`, `.replay`, `.generate`, `.shrink`
- Run reports, notes, events, target scores, and health warnings:
  - `Sources/PremiseCore/RunReport.swift`
  - `Sources/PremiseCore/PremiseData.swift`
- Data-aware draws via `PremiseData.draw(_:)`
- Scoped type-driven strategy registry:
  - `Sources/PremiseStrategies/StrategyDerivation.swift`
- Rule-based state machine DSL:
  - `Sources/PremiseTesting/RuleBasedStateMachine.swift`
- Parallel runner, telemetry sidecar, coverage sidecar, and SMT target scaffold:
  - `Sources/PremiseParallel/`
  - `Sources/PremiseTelemetry/`
  - `Sources/PremiseCoverageGuided/`
  - `Sources/PremiseSMT/`

The prior foundation plan in `docs/superpowers/plans/2026-06-04-hypothesis-parity-foundation.md` appears mostly implemented.

## Missing or Partial Feature Areas

### P0 — User-Facing API Parity

#### 1. Explicit examples are not exposed through adapters

Current state:

- `Runner.runDetailed(explicitExamples:)` exists.
- `forAll`, `premise_forAll`, and `@given` do not expose Hypothesis-style explicit examples.

Missing:

- Adapter-level explicit examples.
- `@given` macro support for examples.
- Expected-failure examples similar to `example.xfail`.
- Optional origin labels similar to `example.via`.

#### 2. Property-body assumptions are missing

Current state:

- `Strategy.assume` and `Strategy.suchThat` exist as generation filters.

Missing:

- Hypothesis-style `assume(condition)` inside a property body.
- `reject()` / discard support after observing generated values.
- Rejection metadata in run reports and health checks.

#### 3. Settings parity is partial

Current state:

- `PropertyConfig` has max runs, shrink iterations, draw budget, seed, replay, timeout, phases, and health checks.

Missing:

- Per-example deadline distinct from whole-run timeout.
- Verbosity levels.
- Settings profiles: default, CI, and custom named profiles.
- Derandomized seed derived from property identity.
- Print/reproduce failure blob setting.
- Multiple-bug reporting policy.
- Backend selection.
- Health-check suppression model.

#### 4. Replay tooling is missing

Current state:

- Failure records and exported JSON artifacts exist.
- `.planning/REQUIREMENTS.md` already tracks `TOOL-01`.

Missing:

- SwiftPM command plugin to replay a stored trace.
- Stable CLI-facing trace blob.
- Copy-paste reproduction output equivalent to Hypothesis `@reproduce_failure`.

### P1 — Engine and Search Parity

#### 5. Targeted property-based testing is only diagnostic

Current state:

- `PremiseData.target` records max target scores.

Missing:

- `.target` phase.
- Trace mutation / hill-climbing search.
- Corpus prioritization by target score.
- Search steering based on `target()` observations.

#### 6. Coverage-guided integration is not wired

Current state:

- `PremiseCoverageGuided` has `CoverageMap`, `CoverageTracker`, and `EdgeCountGuide`.

Missing:

- Real LLVM SanitizerCoverage integration.
- Graceful fallback when instrumentation is absent.

Tracked already by:

- `COVR-02`
- `COVR-03`

#### 7. Explain phase is missing

Missing:

- `PropertyPhase.explain`.
- Best-effort suspicious-line or argument-variation explanation after shrinking.
- Failure output comments explaining which values may vary without changing the failure.

#### 8. Flakiness detection is missing

Missing:

- Failure-found-but-not-reproducible detection.
- Different-error-on-replay detection.
- Strategy nondeterminism detection.
- Typed errors analogous to Hypothesis `Flaky`, `FlakyFailure`, and `FlakyStrategyDefinition`.

#### 9. Multiple bug reporting is missing

Current state:

- Premise returns the first failure.

Missing:

- Collecting multiple distinct failures in one run.
- Distinct failure grouping by origin / error / trace shape.
- Adapter diagnostics for multiple failures.

#### 10. Shrink quality is partial

Current state:

- Core trace shrinking exists.
- Value-level shrinkers exist for many basic strategies.

Partial/missing:

- `map`, `flatMap`, `oneOf`, `frequency`, and `recursive` mostly have empty shrinkers.
- Stateful testing does not shrink failing programs.

### P1 — Strategy Catalog Parity

Current catalog includes primitives, arrays, dictionaries, sets, strings, dates, UUIDs, URLs, recursive data, vectors, and index workflow strategies.

Missing high-value Hypothesis strategy equivalents:

- `nothing()` / never strategy.
- Richer sampled-from / enum support.
- Fixed dictionaries / record-shaped strategies.
- Unique arrays by value or key.
- Regex-generated strings.
- Unicode category and codepoint filtering.
- Email, domain, IP address strategies.
- More complete URL strategy.
- Decimal, rational, and complex-number equivalents where Swift has suitable types.
- Time, date-time, timezone, duration, and calendar strategies.
- UUID version and nil UUID options.
- Slice/range/index strategies.
- Generated functions / callbacks.
- Shared values per run.
- Deferred / mutually recursive strategies.
- Ergonomic composite strategy builder.

### P1 — Stateful Testing Parity

Current state:

- `RuleBasedStateMachine` exists with rules, preconditions, invariants, and bundles.

Missing:

- Initialization rules.
- Teardown.
- Consuming bundles.
- Multiple rule outputs.
- Invariant `checkDuringInit`.
- Shrinking failing operation sequences.
- Persisted/replayable state-machine programs.
- Printable minimal failing program.
- Integration with `PropertyConfig` stateful settings.

### P2 — Tooling and Ecosystem Parity

#### 11. Ghostwriter is missing

Current state:

- README explicitly says ghostwriter is separate.

Missing:

- `PremiseGhostwriter` executable or SwiftPM command plugin.
- Test generation for:
  - fuzz / no-crash properties
  - roundtrip encode/decode
  - equivalence / differential tests
  - idempotence
  - binary operation laws

#### 12. External fuzzer bridge is missing

Missing:

- Hypothesis-style `fuzzOneInput(bytes)`.
- Byte-buffer provider.
- Canonical/pruned bytes on pass.
- Saving failing inputs to Premise database.
- libFuzzer/AFL workflow documentation.

#### 13. JSONL observability is missing

Current state:

- `PremiseTelemetry` sidecar exists.

Missing:

- `PropertyConfig.telemetry` injection.
- Structured JSON Lines output.
- Per-test-case observations.
- Timing, phase, coverage, event, target score, and failure metadata.

Tracked already by:

- `TOOL-02`
- `TELM-02`

#### 14. Build/plugin tooling is missing

Tracked already by:

- `TOOL-03`: restricted-import build plugin.

Missing:

- SwiftPM build plugin integration.
- Tests proving restricted imports fail the build.

## Recommended Implementation Plan

### Phase 1 — Adapter and Settings Parity

**Goal:** Expose already-existing core capabilities through ergonomic public APIs and close basic Hypothesis API gaps.

Likely files:

- `Sources/PremiseCore/PropertyConfig.swift`
- `Sources/PremiseCore/PremiseData.swift`
- `Sources/PremiseCore/RunReport.swift`
- `Sources/PremiseTesting/ForAll.swift`
- `Sources/PremiseXCTest/PremiseForAll.swift`
- `Sources/PremiseMacrosPlugin/GivenMacro.swift`
- Adapter and macro tests under `Tests/`

Tasks:

- [x] Add `ExplicitExample<Value>` with:
  - value
  - optional label/origin
  - expected-failure metadata
- [x] Add explicit examples to `forAll`.
- [x] Add explicit examples to `premise_forAll`.
- [x] Add explicit examples to `@given` macro syntax.
- [x] Add `PremiseData.assume(_:)` and `PremiseData.reject()`.
- [x] Teach `Runner` to distinguish draw rejection from property-body rejection.
- [x] Add per-example deadline, verbosity, derandomize, printBlob, and multiple-bug config scaffolding.
- [x] Add focused adapter and runner tests; validate macro syntax with source macro build.

Validation:

```bash
swift test --filter PhaseAndReportTests
swift test --filter DataAwareForAllTests
swift test --filter PremiseTestingIntegrationTests
swift test --filter PremiseXCTestIntegrationTests
PREMISE_MACRO_SOURCE=1 swift test --filter Macro
```

### Phase 2 — Replay and Trace Tooling

**Goal:** Match Hypothesis reproduction ergonomics.

Likely files:

- `Sources/PremiseCore/ChoiceTrace.swift`
- `Sources/PremiseDatabase/PersistenceCodec.swift`
- `Package.swift`
- new plugin/executable target, e.g. `PremiseReplayPlugin` or `PremiseReplayTool`

Tasks:

- [ ] Add stable binary trace/blob encoding or finish ARD binary CBOR trace work.
- [ ] Add typed unsupported-version errors for replay blobs.
- [ ] Add copy-paste reproduction output in failure formatter.
- [ ] Add SwiftPM command plugin: `swift package premise-replay <trace-path>`.
- [ ] Add JSONL run output mode.

Validation:

```bash
swift test --filter ChoiceTraceTests
swift test --filter PersistenceFormatCompatibilityTests
swift package dump-package > /tmp/premise-dump.json
```

### Phase 3 — Search Parity

**Goal:** Make `target()` and coverage guide exploration instead of only reporting observations.

Likely files:

- `Sources/PremiseCore/PropertyPhase.swift`
- `Sources/PremiseCore/Runner.swift`
- `Sources/PremiseCoverageGuided/`
- new C shim target if needed for SanitizerCoverage

Tasks:

- [ ] Add `PropertyPhase.target`.
- [ ] Add trace mutation provider / corpus prioritizer.
- [ ] Use `PremiseData.target` to steer generation.
- [ ] Wire LLVM SanitizerCoverage into `PremiseCoverageGuided`.
- [ ] Add graceful fallback when coverage instrumentation is absent.
- [ ] Add flakiness detection.
- [ ] Add multiple-failure collection and reporting.

Validation:

```bash
swift test --filter PremiseCoverageGuidedTests
swift test --filter Runner
swift build --traits CoverageGuided
```

### Phase 4 — Strategy Catalog Expansion

**Goal:** Close high-value built-in strategy gaps.

Likely files:

- `Sources/PremiseStrategies/`
- `Tests/PremiseStrategiesTests/`
- `Sources/PremiseCore/Documentation.docc/Articles/StrategyCatalog.md`

Priority order:

- [ ] `Strategy.nothing()` / never strategy.
- [ ] Regex string generation.
- [ ] IP/domain/email strategies.
- [ ] More complete URL strategy.
- [ ] Date/time/timezone/duration strategies.
- [ ] Fixed dictionary / record strategies.
- [ ] Unique arrays by value/key.
- [ ] Decimal/rational/complex equivalents where appropriate.
- [ ] Deferred/shared/generated-function strategies.
- [ ] Composite strategy builder ergonomics.

Validation:

```bash
swift test --filter PremiseStrategiesTests
swift test --filter StrategyReleaseReadinessTests
```

### Phase 5 — Stateful Testing Parity

**Goal:** Reach Hypothesis-style minimal failing state-machine programs.

Likely files:

- `Sources/PremiseTesting/RuleBasedStateMachine.swift`
- `Tests/PremiseTestingIntegrationTests/RuleBasedStateMachineTests.swift`

Tasks:

- [ ] Represent stateful runs as shrinkable operation traces.
- [ ] Add initialize rules.
- [ ] Add teardown.
- [ ] Add consuming bundles.
- [ ] Add multiple bundle outputs.
- [ ] Add invariant `checkDuringInit`.
- [ ] Shrink failing rule sequences and rule arguments.
- [ ] Persist and replay state-machine failures.
- [ ] Print minimal failing programs.

Validation:

```bash
swift test --filter RuleBasedStateMachineTests
```

### Phase 6 — Ghostwriter and Fuzzer Bridge

**Goal:** Match Hypothesis tooling differentiators.

Likely files:

- `Package.swift`
- new `Sources/PremiseGhostwriter/`
- new `Sources/PremiseFuzzing/`
- new tests under `Tests/PremiseGhostwriterTests/` and `Tests/PremiseFuzzingTests/`

Tasks:

- [ ] Add `PremiseGhostwriter` executable or SwiftPM command plugin.
- [ ] Generate fuzz/no-crash test skeletons.
- [ ] Generate roundtrip tests.
- [ ] Generate equivalence/differential tests.
- [ ] Generate idempotence tests.
- [ ] Generate binary operation law tests.
- [ ] Add `FuzzInputProvider`.
- [ ] Add `fuzzOneInput` API.
- [ ] Save failing fuzz inputs to the database.
- [ ] Document libFuzzer/AFL integration.

Validation:

```bash
swift test --filter PremiseGhostwriterTests
swift test --filter PremiseFuzzingTests
swift build
```

## Suggested Next Step

Start with **Phase 1 — Adapter and Settings Parity**. It is the lowest-risk slice because most supporting machinery already exists in core. The work primarily exposes missing public APIs and improves diagnostics/configuration before deeper engine/search work.

## Notes

- Keep `PremiseCore` macro-free and storage-neutral.
- Keep optional tooling in leaf targets or plugins.
- Avoid adding Python-specific concepts that do not map cleanly to Swift; prefer Swift-native API names while preserving Hypothesis-equivalent behavior.
- The existing v1.1 roadmap already covers several lower-level trace/tooling requirements. This plan should be merged with `.planning/REQUIREMENTS.md` before implementation begins.
