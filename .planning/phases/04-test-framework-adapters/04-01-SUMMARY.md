---
phase: "04"
plan: "01"
subsystem: adapters
tags: [swift-testing, xctest, forAll, conjecture_forAll, adapter]
dependency_graph:
  requires: [ConjectureCore, ConjectureDatabase, ConjectureStrategies, ReplayFirstExecutor]
  provides: [forAll, conjecture_forAll, FailureFormatter, XCTestFailureFormatter]
  affects: [ConjectureTesting, ConjectureXCTest]
tech_stack:
  added: []
  patterns: [ReplayFirstExecutor-driven adapter, source-location passthrough, XCTExpectFailure for expected-failure tests]
key_files:
  created:
    - Sources/ConjectureTesting/FailureFormatter.swift
    - Sources/ConjectureXCTest/XCTestFailureFormatter.swift
    - Tests/ConjectureTestingIntegrationTests/ForAllIntegrationTests.swift
    - Tests/ConjectureXCTestIntegrationTests/ConjectureForAllIntegrationTests.swift
  modified:
    - Sources/ConjectureTesting/ForAll.swift
    - Sources/ConjectureXCTest/ConjectureForAll.swift
decisions:
  - Used fileID (module-relative) rather than filePath (absolute) for PropertyIdentity to keep hex-encoded database filenames within filesystem limits
  - Kept FailureFormatter internal to each adapter module to avoid cross-dependencies between ConjectureTesting and ConjectureXCTest
metrics:
  duration: 4min
  completed: 2026-03-30
---

# Phase 04 Plan 01: Test Framework Adapter Implementations Summary

Replaced Phase 1 placeholder stubs with working swift-testing forAll and XCTest conjecture_forAll adapters wired through ReplayFirstExecutor with structured failure diagnostics.

## What Was Done

### Task 1: swift-testing forAll adapter (3b1dc97)
- Replaced the no-op placeholder with a working `forAll` that constructs a `PropertyIdentity`, builds a `Runner`, wraps it in `ReplayFirstExecutor` with `FileBackedDatabase`, and reports failures via `Issue.record` with source location passthrough.
- Created `FailureFormatter` for structured counterexample output (value, error, run/shrink counts, replay instruction).
- Supports per-property config and async/throws closures under Swift 6 strict concurrency.

### Task 2: XCTest conjecture_forAll adapter (61118da)
- Replaced the no-op placeholder with a working `conjecture_forAll` that drives `ReplayFirstExecutor` and reports failures via `XCTFail` at the caller's source location.
- Created `XCTestFailureFormatter` with the same structured output format.
- Added `fileID` parameter (defaulted to `#fileID`) for module-relative property identity.

### Task 3: Adapter integration tests (7214f7a)
- Added 4 swift-testing tests: passing property, custom config, failing property (withKnownIssue), and failure output verification.
- Added 4 XCTest tests: passing property, custom config, failing property with counterexample verification (XCTExpectFailure), and replay instruction verification.
- Fixed XCTest adapter to use `#fileID` instead of `#filePath` for property identity to avoid hex-encoded filenames exceeding filesystem limits.

### Task 4: Build and verify zero-warning compilation
- `swift build` produces zero warnings under Swift 6 strict concurrency.
- All 26 tests pass (5 XCTest + 21 swift-testing).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed file name too long error in XCTest adapter**
- **Found during:** Task 3
- **Issue:** XCTest's `#filePath` returns the full absolute path which, when hex-encoded for the FileBackedDatabase filename, exceeds macOS's 255-byte filename limit.
- **Fix:** Added `fileID` parameter defaulted to `#fileID` (module-relative path) to the `conjecture_forAll` signature, keeping `file` for XCTFail source location.
- **Files modified:** Sources/ConjectureXCTest/ConjectureForAll.swift
- **Commit:** 7214f7a

## Decisions Made

1. **fileID for identity, filePath for diagnostics**: The XCTest adapter uses `#fileID` (module-relative) for `PropertyIdentity` to keep database filenames short, while preserving `#filePath` for `XCTFail` source location accuracy.
2. **Separate formatters per module**: Each adapter module has its own internal formatter (`FailureFormatter` / `XCTestFailureFormatter`) to avoid cross-dependencies.

## Known Stubs

None -- all adapter entry points are fully wired to `ReplayFirstExecutor`.

## Self-Check: PASSED
