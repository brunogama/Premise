# PremiseReplayTool

## Overview

Command-line inspection of persisted failures and reproduction traces.

---

## Interface

- `swift package premise-replay --help` describes file, blob, and JSON output options.
- Inputs include failure artifacts, persisted envelopes, raw choice-trace JSON, and reproduction blobs.

---

## Invariants

- Reproduction blobs are decoded with their stable header and version validation; unrecognized inputs report an error.

---

## Side Effects

- Reads an input file when the argument names an existing path; writes summaries or errors to standard output or standard error.

---

## Verification

- From the repository root, run `swift test`.
