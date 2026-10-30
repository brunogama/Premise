# CPremiseSanitizerCoverage

## Overview

Implements the C sanitizer-coverage callbacks and a compact coverage bitmap.

---

## Interface

- The [public header](./include/README.md) documents `premise_sancov_edge_count`, `premise_sancov_snapshot`, and `premise_sancov_reset`.
- The sanitizer invokes `__sanitizer_cov_trace_pc_guard_init` and `__sanitizer_cov_trace_pc_guard`.

---

## Invariants

- Coverage is limited to 65,536 edges; snapshot copies no more bytes than the supplied buffer can hold.
- Reset clears edge observations, not the guard count.

---

## Side Effects

- Callbacks and reset mutate process-wide atomic coverage state; snapshot writes to a caller-owned buffer.

---

## Verification

- From the repository root, run `swift test`.
