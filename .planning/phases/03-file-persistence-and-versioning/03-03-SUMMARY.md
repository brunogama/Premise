---
phase: 03-file-persistence-and-versioning
plan: "03"
subsystem: database
tags: [replay, persistence, executor, integration-test]

requires:
  - phase: 03-02
    provides: FileBackedDatabase with save/load/clear operations
  - phase: 02-01
    provides: Runner with replay-first run method
provides:
  - ReplayFirstExecutor bridging Runner and ExampleDatabase
  - Integration test coverage for replay ordering and failure persistence
affects: [ConjectureTesting, ConjectureXCTest, phase-04]

tech-stack:
  added: []
  patterns: [replay-first execution pattern, storage-neutral core]

key-files:
  created:
    - Sources/ConjectureDatabase/ReplayFirstExecutor.swift
    - Tests/ConjectureDatabaseTests/ReplayOrderingIntegrationTests.swift
    - Sources/ConjectureCore/Runner.swift
    - Sources/ConjectureCore/RunResult.swift
  modified: []

key-decisions:
  - "ReplayFirstExecutor uses composition (Runner + ExampleDatabase) rather than inheritance"
  - "Runner.swift and RunResult.swift added as blocking dependencies from phase 02"

patterns-established:
  - "Executor pattern: bridge between storage-neutral core and persistence boundary"
  - "Integration tests use FileBackedDatabase with temp directories for isolation"

requirements-completed: [PERS-02, PERS-01]

duration: 2min
completed: 2026-03-30
---

# Phase 03 Plan 03: Replay-First Executor Summary

**ReplayFirstExecutor wiring persisted traces through FileBackedDatabase before fresh generation with full integration test coverage**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-30T07:47:05Z
- **Completed:** 2026-03-30T07:49:25Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- ReplayFirstExecutor loads traces, runs property, and persists failures at the database boundary
- Integration tests prove replay runs before fresh generation (maxRuns: 0 scenario)
- Integration tests verify failure persistence round-trip through the executor

## Task Commits

Each task was committed atomically:

1. **Task 1: Add replay-first executor at the database boundary** - `e7d0d02` (feat)
2. **Task 2: Add integration tests for replay-before-fresh behavior** - `df658b3` (test)

## Files Created/Modified
- `Sources/ConjectureDatabase/ReplayFirstExecutor.swift` - Replay-first executor bridging Runner and ExampleDatabase
- `Tests/ConjectureDatabaseTests/ReplayOrderingIntegrationTests.swift` - Integration tests for replay ordering and persistence
- `Sources/ConjectureCore/Runner.swift` - Property runner with replay-first run method (added as dependency)
- `Sources/ConjectureCore/RunResult.swift` - Result enum for property runs (added as dependency)

## Decisions Made
- ReplayFirstExecutor uses composition (accepts Runner and ExampleDatabase) rather than subclassing, keeping ConjectureCore storage-neutral
- Runner marked Sendable to satisfy strict concurrency requirements in Swift 6 mode

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added Runner.swift and RunResult.swift from phase 02**
- **Found during:** Task 1
- **Issue:** Runner.swift and RunResult.swift did not exist in this worktree branch, blocking ReplayFirstExecutor compilation
- **Fix:** Created both files matching the phase 02 implementation
- **Files modified:** Sources/ConjectureCore/Runner.swift, Sources/ConjectureCore/RunResult.swift
- **Verification:** swift build --target ConjectureDatabase passes with zero warnings
- **Committed in:** e7d0d02

**2. [Rule 1 - Bug] Runner missing Sendable conformance**
- **Found during:** Task 1
- **Issue:** Runner struct not conforming to Sendable caused compilation error in Swift 6 strict concurrency mode when stored in Sendable ReplayFirstExecutor
- **Fix:** Added `: Sendable` conformance to Runner declaration
- **Files modified:** Sources/ConjectureCore/Runner.swift
- **Verification:** swift build passes with -warnings-as-errors
- **Committed in:** e7d0d02

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Both fixes necessary for compilation. No scope creep.

## Issues Encountered
None beyond the deviations documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Replay-first execution path complete and tested
- Ready for adapter integration in phase 04
- ConjectureTesting and ConjectureXCTest can wire through ReplayFirstExecutor

---
*Phase: 03-file-persistence-and-versioning*
*Completed: 2026-03-30*
