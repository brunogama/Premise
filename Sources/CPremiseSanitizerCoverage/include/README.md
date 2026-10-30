# Sanitizer Coverage Header

## Overview

C interface for the sanitizer coverage runtime.

---

## Interface

- `premise_sancov_edge_count`, `premise_sancov_snapshot`, and `premise_sancov_reset` are declared in `premise_sanitizer_coverage.h`.

---

## Invariants

- The snapshot function accepts a buffer and its capacity in bytes and returns the number of bytes copied.

---

## Side Effects

- The runtime reads and resets process-wide coverage state; snapshot writes into the caller's buffer.

---

## Verification

- From the repository root, run `swift test`.
