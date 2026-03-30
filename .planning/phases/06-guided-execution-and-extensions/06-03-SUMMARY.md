---
phase: 06-guided-execution-and-extensions
plan: 03
subsystem: coverage-guided
tags: [coverage-guidance, bitmap, actor, sendable, sidecar, extension-module]

requires:
  - phase: 06-guided-execution-and-extensions
    plan: 01
    provides: SwiftPM trait-gated manifest with ConjectureCoverageGuided target
provides:
  - CoverageMap bitmap-based edge tracker with merge and diff
  - CoverageGuide protocol for stateless coverage scoring
  - EdgeCountGuide implementation counting novel edges
  - CoverageTracker actor for thread-safe cumulative state
affects: []

tech-stack:
  added: []
  patterns: [bitmap-edge-tracking, stateless-scoring-protocol, actor-owned-cumulative-state]

key-files:
  created:
    - Sources/ConjectureCoverageGuided/CoverageMap.swift
    - Sources/ConjectureCoverageGuided/CoverageGuide.swift
    - Sources/ConjectureCoverageGuided/EdgeCountGuide.swift
    - Sources/ConjectureCoverageGuided/CoverageTracker.swift
    - Tests/ConjectureCoverageGuidedTests/CoverageMapTests.swift
  modified:
    - Tests/ConjectureCoverageGuidedTests/CoverageGuidanceIsolationTests.swift

key-decisions:
  - "Separated stateless CoverageGuide protocol from stateful CoverageTracker actor for clean concurrency"
  - "CoverageMap uses UInt8 bitmap for compact edge tracking without external dependencies"
  - "EdgeCountGuide is stateless struct; cumulative state lives in CoverageTracker actor"

patterns-established:
  - "Stateless guide + actor tracker: scoring logic is pure, state management is actor-isolated"
  - "Bitmap edge map: compact O(1) per-edge operations without hash table overhead"

requirements-completed: [COVR-01]

duration: 3min
completed: 2026-03-30
---

# Phase 6 Plan 3: Coverage-Guided Exploration Module Summary

**Bitmap-based coverage map with stateless scoring protocol and actor-owned cumulative tracker for sidecar coverage guidance**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-30T08:51:19Z
- **Completed:** 2026-03-30T08:54:46Z
- **Tasks:** 1
- **Files modified:** 7

## Accomplishments

- CoverageMap provides compact bitmap-based edge tracking with O(1) record/query, merge, diff, and reset operations
- CoverageGuide protocol defines a stateless scoring contract that evaluates snapshots against baselines
- EdgeCountGuide implements the simplest useful guide: score = count of novel edges
- CoverageTracker actor owns cumulative state and provides thread-safe recording interface
- All 18 tests pass covering map operations, guide scoring, tracker accumulation, sidecar isolation, and Runner independence
- Default build (no traits) succeeds with zero warnings

## Task Commits

1. **Task 1: Implement ConjectureCoverageGuided module** - `419f6a7` (feat)

## Files Created/Modified

- `Sources/ConjectureCoverageGuided/CoverageMap.swift` - Bitmap-based edge coverage tracker
- `Sources/ConjectureCoverageGuided/CoverageGuide.swift` - Stateless scoring protocol and CoverageScore value type
- `Sources/ConjectureCoverageGuided/EdgeCountGuide.swift` - Novel edge count scoring implementation
- `Sources/ConjectureCoverageGuided/CoverageTracker.swift` - Actor for thread-safe cumulative coverage state
- `Tests/ConjectureCoverageGuidedTests/CoverageMapTests.swift` - 10 tests for map operations
- `Tests/ConjectureCoverageGuidedTests/CoverageGuidanceIsolationTests.swift` - 8 tests for guide, tracker, and sidecar isolation
- `Sources/ConjectureCoverageGuided/ConjectureCoverageGuided.swift` - Removed stub namespace marker

## Decisions Made

- Separated stateless CoverageGuide protocol from stateful CoverageTracker actor: scoring logic is pure and testable, state management uses actor isolation for Sendable compliance
- CoverageMap uses UInt8 bitmap array for compact edge tracking without hash table overhead
- EdgeCountGuide is a zero-state struct; cumulative state management delegated to CoverageTracker actor
- Removed old namespace stub since module now has real content

## Deviations from Plan

None - plan executed exactly as written. The plan file did not exist on disk so execution was derived from the ROADMAP requirement COVR-01 and the phase research document.

## Known Stubs

None. All coverage-guided types are fully implemented with real logic.

## Issues Encountered

None.

## User Setup Required

None - coverage-guided module is opt-in via SwiftPM CoverageGuided trait.

## Next Phase Readiness

- Coverage guidance types are ready for integration with guided runners
- CoverageTracker can be composed with parallel execution when ConjectureParallel lands
- The CoverageGuide protocol is extensible for future scoring strategies beyond edge counting

## Self-Check: PASSED

- All 6 created files verified present on disk
- Commit 419f6a7 verified in git log
- 18/18 tests pass
- Default build succeeds with zero warnings

---
*Phase: 06-guided-execution-and-extensions*
*Completed: 2026-03-30*
