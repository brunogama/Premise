# PremiseFuzzing

## Overview

Bridges byte-oriented external fuzzers to Premise strategies.

---

## Interface

- `FuzzInputProvider`, `FuzzConfig`, `FuzzOutcome`, `FuzzRunResult`, `FuzzFailure`, and `fuzzOneInput` represent and execute fuzz inputs.

---

## Invariants

- Input bytes are consumed in order; incomplete draws are zero-padded and mark the provider exhausted.
- An exhausted input skips the property body; rejected inputs are distinguished from failures.

---

## Side Effects

- Fuzzing executes caller-provided strategy and property code; configured failures may be persisted to disk.

---

## Verification

- From the repository root, run `swift test`.
