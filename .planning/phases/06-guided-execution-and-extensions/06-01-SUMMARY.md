---
phase: 06-guided-execution-and-extensions
plan: 01
subsystem: infra
tags: [swiftpm-traits, telemetry, actor, sendable, extension-modules]

requires:
  - phase: 05-sqlite-wal-persistence
    provides: stable v1 core with persistence boundary
provides:
  - SwiftPM trait declarations for CoverageGuided, Telemetry, SMT
  - Extension source targets PremiseParallel, PremiseTelemetry, PremiseCoverageGuided, PremiseSMT, CZ3
  - Extension test targets for all four modules
  - PremiseTelemetry module with EngineEvent, TelemetrySink, TelemetryRelay
affects: [06-02, 06-03, 06-04]

tech-stack:
  added: [swiftpm-traits, system-library-cz3]
  patterns: [trait-gated-leaf-targets, sidecar-telemetry-actor, event-enum-observation]

key-files:
  created:
    - Package.swift (updated with traits and extension targets)
    - Sources/PremiseTelemetry/EngineEvent.swift
    - Sources/PremiseTelemetry/TelemetrySink.swift
    - Sources/PremiseTelemetry/TelemetryRelay.swift
    - Sources/CZ3/module.modulemap
    - Sources/CZ3/cz3.h
    - Tests/PremiseTelemetryTests/TelemetryHookSemanticsTests.swift
  modified:
    - Package.swift

key-decisions:
  - "Used SwiftPM traits with empty default set to keep extension modules opt-in"
  - "Implemented TelemetryRelay as actor for Sendable fan-out without locks"
  - "EngineEvent is enum with associated values, not protocol hierarchy, for exhaustive matching"

patterns-established:
  - "Trait-gated leaf targets: extension modules use .when(traits:) for conditional deps and build settings"
  - "Sidecar telemetry: events are observational-only with no back-edge into core types"
  - "Actor relay: fan-out pattern using actor isolation for thread-safe sink registration"

requirements-completed: [TELE-01]

duration: 4min
completed: 2026-03-30
---

# Phase 6 Plan 1: Manifest Traits and Telemetry Hooks Summary

**SwiftPM trait-gated extension manifest with PremiseTelemetry actor relay for sidecar engine event observation**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-30T08:43:36Z
- **Completed:** 2026-03-30T08:47:30Z
- **Tasks:** 2
- **Files modified:** 15

## Accomplishments
- Package.swift updated with 3 SwiftPM traits (CoverageGuided, Telemetry, SMT) and 5 extension source targets + 4 test targets
- PremiseTelemetry module delivers EngineEvent enum, TelemetrySink protocol, and TelemetryRelay actor under Swift 6 strict concurrency
- All 6 telemetry tests pass with sidecar semantics verified (events do not affect RunResult)
- Default build (no traits) succeeds with zero warnings

## Task Commits

Each task was committed atomically:

1. **Task 1: Update Package.swift with trait-gated extension targets** - `7982389` (feat)
2. **Task 2 RED: Failing telemetry tests** - `5089e02` (test)
3. **Task 2 GREEN: Implement PremiseTelemetry module** - `6712cfe` (feat)

## Files Created/Modified
- `Package.swift` - Added traits block, 5 extension source targets, CZ3 system library, 4 extension test targets
- `Sources/PremiseTelemetry/EngineEvent.swift` - Observable engine event enum with 4 cases
- `Sources/PremiseTelemetry/TelemetrySink.swift` - Sendable protocol for event observation
- `Sources/PremiseTelemetry/TelemetryRelay.swift` - Actor-based fan-out relay for registered sinks
- `Sources/PremiseParallel/PremiseParallel.swift` - Namespace stub for parallel module
- `Sources/PremiseCoverageGuided/PremiseCoverageGuided.swift` - Namespace stub for coverage module
- `Sources/PremiseSMT/PremiseSMT.swift` - Namespace stub for SMT module
- `Sources/CZ3/module.modulemap` - System library module map for Z3
- `Sources/CZ3/cz3.h` - C header shim for Z3
- `Tests/PremiseTelemetryTests/TelemetryHookSemanticsTests.swift` - 6 tests for event relay semantics
- `Tests/PremiseParallelTests/ParallelDeterminismTests.swift` - Empty test suite placeholder
- `Tests/PremiseCoverageGuidedTests/CoverageGuidanceIsolationTests.swift` - Empty test suite placeholder
- `Tests/PremiseSMTTests/SMTProviderOptInTests.swift` - Empty test suite placeholder

## Decisions Made
- Used SwiftPM traits with empty default set so extension modules are strictly opt-in
- Implemented TelemetryRelay as an actor (not class+lock) for natural Sendable compliance
- EngineEvent uses enum with associated values for exhaustive switch matching rather than protocol hierarchy
- Stub files use `enum ModuleName {}` namespace marker to avoid Swift 6 empty-module warnings

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Strategy init and drawInteger API mismatch in test**
- **Found during:** Task 2 (TDD GREEN phase)
- **Issue:** Test used `Strategy<Int> { ... }` without required `label` parameter and `drawInteger(from:)` instead of `drawInteger(in:)`
- **Fix:** Updated to `Strategy<Int>(label: "testInt") { data in data.drawInteger(in: 0...100) }`
- **Files modified:** Tests/PremiseTelemetryTests/TelemetryHookSemanticsTests.swift
- **Verification:** All 6 tests pass
- **Committed in:** 6712cfe (Task 2 GREEN commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** API label mismatch in test code only. No scope creep.

## Known Stubs

| File | Line | Reason |
|------|------|--------|
| Sources/PremiseParallel/PremiseParallel.swift | 2 | Placeholder for Wave 2 plan 06-02 |
| Sources/PremiseCoverageGuided/PremiseCoverageGuided.swift | 2 | Placeholder for Wave 2 plan 06-03 |
| Sources/PremiseSMT/PremiseSMT.swift | 2 | Placeholder for Wave 2 plan 06-04 |

All stubs are intentional namespace markers for modules that will be implemented by later plans in this phase.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Package manifest is ready for all Phase 06 Wave 2 plans to implement their respective modules
- PremiseTelemetry is complete and can be consumed by parallel/coverage modules for event emission
- SMT trait requires Z3 to be installed via Homebrew (`brew install z3`) when enabled

---
*Phase: 06-guided-execution-and-extensions*
*Completed: 2026-03-30*
