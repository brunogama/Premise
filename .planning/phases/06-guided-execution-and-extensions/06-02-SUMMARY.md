---
phase: 06-guided-execution-and-extensions
plan: 02
subsystem: parallel-execution
tags: [parallel, task-group, deterministic-seeding, sendable, structured-concurrency]

requires:
  - phase: 06-guided-execution-and-extensions
    plan: 01
    provides: trait-gated PremiseParallel target in Package.swift
provides:
  - ParallelRunner with deterministic seed-per-index mapping
  - ParallelConfig for concurrent run limits
  - ResultCollector actor for lowest-index failure normalization
affects: []

tech-stack:
  added: []
  patterns: [logical-index-parallel-scheduling, actor-result-collection, completion-order-normalization]

key-files:
  created:
    - Sources/PremiseParallel/ParallelConfig.swift
    - Sources/PremiseParallel/ParallelRunner.swift
    - Tests/PremiseParallelTests/ParallelDeterminismTests.swift
  modified: []

decisions:
  - Used ResultCollector actor to track lowest-index failure instead of array-based normalization
  - Sequential fallback for maxRuns <= 1 to avoid task group overhead
  - Replay traces execute sequentially before parallel generation, matching Runner semantics

metrics:
  duration: 3min
  completed: 2026-03-30
  tasks: 2
  files: 4
---

# Phase 06 Plan 02: PremiseParallel Deterministic Parallel Execution Summary

ParallelRunner distributes property runs across a Swift task group with seed-per-index mapping matching the sequential Runner contract, using a ResultCollector actor to normalize results by lowest failure index.

## What Was Done

### Task 1: Implement ParallelRunner with deterministic seed distribution
**Commit:** e775876

Created `ParallelConfig` with optional `maxConcurrentRuns` and `ParallelRunner<Value>` that:
- Maps each logical run index to `baseSeed + UInt64(runIndex)`, identical to sequential `Runner`
- Uses `withTaskGroup` with a `ResultCollector` actor that tracks only the lowest-index failure
- Applies throttling when `maxConcurrentRuns` is set
- Falls back to sequential execution for `maxRuns <= 1`
- Replays traces sequentially before parallel generation

### Task 2: Add determinism and parallel execution tests
**Commit:** 10d9511

Six tests in `ParallelDeterminismTests`:
1. Same seed produces identical results in parallel and sequential mode
2. Lowest-index failure returned regardless of scheduling
3. All runs pass correctly
4. Single run works correctly
5. Replay traces execute before generation
6. Seed-per-index mapping matches sequential Runner for failure detection

## Deviations from Plan

None -- plan executed exactly as written.

## Decisions Made

1. **ResultCollector actor pattern**: Instead of collecting all results into an indexed array, used an actor that only tracks the single lowest-index failure. This avoids allocating a full results array and is more memory-efficient for large run counts.

2. **Sequential fallback**: For `maxRuns <= 1`, the runner avoids task group creation entirely, eliminating overhead for trivial cases.

3. **Replay-first sequential**: Replay traces are always executed sequentially before parallel generation begins, preserving the exact replay-first semantics of the sequential Runner.

## Known Stubs

None.

## Self-Check: PASSED
