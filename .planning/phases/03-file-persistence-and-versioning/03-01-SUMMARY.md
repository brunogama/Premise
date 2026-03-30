---
phase: 03-file-persistence-and-versioning
plan: "01"
subsystem: database
tags: [persistence, versioning, codable, dto, compatibility]

requires:
  - phase: 02-deterministic-trace-engine
    provides: ChoiceTrace and FailureRecord core types
provides:
  - Versioned persistence envelope (PersistedFailureRecordV1) with explicit format versions
  - Compatibility validator rejecting unsupported artifact versions
  - Bidirectional codec mapping between FailureRecord and persistence DTO
affects: [03-file-persistence-and-versioning, 05-sqlite-wal]

tech-stack:
  added: []
  patterns: [versioned-envelope-dto, compatibility-gate-on-decode, persistence-codec-layer]

key-files:
  created:
    - Sources/ConjectureDatabase/PersistenceFormats.swift
    - Sources/ConjectureDatabase/PersistenceCompatibility.swift
    - Sources/ConjectureDatabase/PersistenceCodec.swift
    - Tests/ConjectureDatabaseTests/PersistenceFormatCompatibilityTests.swift
  modified:
    - Sources/ConjectureCore/ConjectureCore.swift
    - Package.swift

key-decisions:
  - "Version policy uses ClosedRange<Int> for supported versions to allow multi-version support in future"
  - "PersistenceCodec validates record version before trace version to fail fast on envelope-level mismatch"

patterns-established:
  - "Versioned envelope DTO: all persistence artifacts use explicit version fields, never raw engine types"
  - "Compatibility gate: every decode path validates versions before constructing runtime types"
  - "Codec layer: PersistenceCodec owns the mapping between core types and persistence DTOs"

requirements-completed: [PERS-03, PERS-04]

duration: 2min
completed: 2026-03-30
---

# Phase 3 Plan 01: Persistence Format Contract Summary

**Versioned persistence DTOs with explicit format-version fields and compatibility gates rejecting unsupported artifact versions**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-30T07:36:31Z
- **Completed:** 2026-03-30T07:38:50Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Defined PersistedFailureRecordV1 envelope with recordFormatVersion and traceFormatVersion fields
- Built PersistenceCompatibilityError with typed unsupportedRecordVersion and unsupportedTraceVersion cases
- Implemented PersistenceCodec with encode/decode/validate ensuring version gates run before FailureRecord construction
- Verified round-trip fidelity and explicit rejection of unsupported future versions in 3 automated tests

## Task Commits

Each task was committed atomically:

1. **Task 1: Create versioned persistence envelopes and validators** - `b2af5c7` (feat)
2. **Task 2: Add compatibility tests for versioned decode behavior** - `190bd8c` (test)

## Files Created/Modified
- `Sources/ConjectureDatabase/PersistenceFormats.swift` - PersistedFailureRecordV1 versioned envelope DTO
- `Sources/ConjectureDatabase/PersistenceCompatibility.swift` - PersistenceCompatibilityError and PersistenceVersionPolicy
- `Sources/ConjectureDatabase/PersistenceCodec.swift` - Bidirectional codec with version validation
- `Tests/ConjectureDatabaseTests/PersistenceFormatCompatibilityTests.swift` - Round-trip and version rejection tests
- `Sources/ConjectureCore/ConjectureCore.swift` - Removed duplicate Phase 1 placeholder types
- `Package.swift` - Added ConjectureCore dependency to ConjectureDatabaseTests target

## Decisions Made
- Version policy uses ClosedRange<Int> to allow multi-version support when v2 formats arrive
- PersistenceCodec validates record version before trace version for fail-fast on envelope-level mismatch

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed duplicate type definitions in ConjectureCore.swift**
- **Found during:** Task 1 (build verification)
- **Issue:** ConjectureCore.swift contained Phase 1 placeholder definitions of ChoiceTrace, ConjectureData, and FailureRecord that conflicted with the evolved separate files from Phase 2
- **Fix:** Replaced the old placeholder content with the evolved FailureRecord (with runCount, shrinkCount, timestamp, engineVersion fields) and removed duplicate ChoiceTrace and ConjectureData
- **Files modified:** Sources/ConjectureCore/ConjectureCore.swift
- **Verification:** swift build --target ConjectureDatabase passes with zero warnings
- **Committed in:** b2af5c7 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Fix was necessary to unblock compilation. No scope creep.

## Issues Encountered
None beyond the auto-fixed blocking issue.

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all types are fully wired with production implementations.

## Next Phase Readiness
- Persistence contract is defined and tested, ready for file-backed database implementation in 03-02
- PersistenceCodec provides the encode/decode bridge that FileBackedDatabase will use for I/O

---
*Phase: 03-file-persistence-and-versioning*
*Completed: 2026-03-30*
