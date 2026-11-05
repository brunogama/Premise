# PremiseCoverageGuided

## Overview

Coverage observations and guides for coverage-guided property exploration.

---

## Interface

- `CoverageMap` records, queries, compares, merges, and resets observed edges.
- `CoverageGuide`, `CoverageScore`, `CoverageTracker`, `EdgeCountGuide`, and `SanitizerCoverage` provide guidance and sanitizer integration.
- Without registered instrumentation guards, `SanitizerCoverage.isAvailable` is false and `snapshot()` returns `nil`.

---

## Invariants

- `CoverageMap` rounds requested capacity to a whole number of bytes and ignores out-of-range edge indices.
- `newEdges(comparedTo:)` reports edges in the other map that are absent from the receiver.

---

## Side Effects

- Recording, merging, and resetting mutate a coverage map. `SanitizerCoverage.reset()` clears process-wide edge hits while preserving guard IDs.

---

## Verification

- From the repository root, run `swift test`.
