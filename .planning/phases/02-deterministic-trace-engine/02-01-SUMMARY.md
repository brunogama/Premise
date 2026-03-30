---
phase: 02-deterministic-trace-engine
plan: "01"
subsystem: infra
tags:
  - choice-trace
  - deterministic-replay
  - primitive-provider
  - swift6
requires: []
provides:
  - Concrete choice-trace model for replayable engine draws
  - Trace-aware mutable draw state for deterministic generation
  - Fresh and replay providers with identical provider semantics
affects:
  - 02-02
  - 02-04
  - phase-03-file-persistence-and-versioning
tech-stack:
  added:
    - Copy-on-write provider boxing for trace-aware draw state
    - Codable trace entries for replay and testing
  patterns:
    - Trace-first generation contract
    - Shared draw API for fresh and replay providers
key-files:
  created:
    - Sources/PremiseCore/ChoiceTrace.swift
    - Sources/PremiseCore/PremiseData.swift
    - Sources/PremiseCore/PseudoRandomProvider.swift
    - Sources/PremiseCore/ReplayProvider.swift
    - Tests/PremiseCoreTests/ChoiceTraceTests.swift
    - Tests/PremiseCoreTests/PrimitiveProviderTests.swift
  modified:
    - Sources/PremiseCore/PrimitiveProvider.swift
    - Sources/PremiseCore/PremiseCore.swift
key-decisions:
  - "Recorded raw draw values in the trace so replay and later shrinking can operate on stable provider outputs rather than reconstructed semantic values."
  - "Kept PremiseData copyable via a provider box so trace-aware generation remains deterministic without forcing reference semantics into the public API."
patterns-established:
  - "Every draw in the engine hot path leaves an explicit trace entry."
  - "Fresh generation and replay generation share the same draw surface."
requirements-completed:
  - CORE-01
duration: 55min
completed: 2026-03-30
---

# Phase 02: Deterministic Trace Engine Summary

**Concrete choice traces with trace-aware draw state and deterministic fresh/replay providers**

## Performance

- **Duration:** 55 min
- **Started:** 2026-03-30T02:45:00Z
- **Completed:** 2026-03-30T03:40:00Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Added `ChoiceTrace` and trace-aware `PremiseData` so every draw can be replayed deterministically.
- Implemented deterministic fresh and replay providers with the same provider contract.
- Added determinism tests for trace recording, Codable round-trips, and replay behavior.

## Task Commits

Implemented in the working tree during Phase 2 execution.

1. **Task 1: Introduce concrete trace and draw-state types** - working tree changes
2. **Task 2: Add fresh and replay providers with determinism tests** - working tree changes

## Files Created/Modified
- `Sources/PremiseCore/ChoiceTrace.swift` - Trace entries and span metadata.
- `Sources/PremiseCore/PremiseData.swift` - Mutable draw state and trace recording.
- `Sources/PremiseCore/PseudoRandomProvider.swift` - Deterministic fresh provider.
- `Sources/PremiseCore/ReplayProvider.swift` - Trace-backed replay provider.
- `Tests/PremiseCoreTests/ChoiceTraceTests.swift` - Trace round-trip coverage.
- `Tests/PremiseCoreTests/PrimitiveProviderTests.swift` - Seed and replay determinism tests.

## Decisions Made
- Stored raw provider draws in the trace so the shrinker can replay and mutate candidates without inventing unrelated values.
- Kept the engine boundary adapter-free and persistence-neutral so later phases can layer storage on top without changing replay semantics.

## Deviations from Plan

None - plan executed as specified.

## Issues Encountered
- No functional blockers. The main constraint was keeping the trace format stable enough for later shrinking and persistence phases.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 2 now has a deterministic trace contract that Phase 2 runner and shrinker work can build on.
- Phase 3 can persist trace-backed failures without changing the provider interface.

---
*Phase: 02-deterministic-trace-engine*
*Completed: 2026-03-30*
