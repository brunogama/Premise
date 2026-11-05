# PremiseParallel

## Overview

Runs property examples concurrently while normalizing results by logical run index.

---

## Interface

- `ParallelConfig` controls the maximum concurrent runs.
- `ParallelRunner` runs properties with optional replay traces and an optional `ExampleDatabase`.

---

## Invariants

- Run index `i` derives its seed from the base seed plus `i`; the lowest-index failure is reported regardless of completion order.
- Enabled replay runs sequentially before parallel generation.

---

## Side Effects

- Execution creates task groups and invokes user properties; an optional database loads replay traces and saves failures.

---

## Verification

- From the repository root, run `swift test`.
