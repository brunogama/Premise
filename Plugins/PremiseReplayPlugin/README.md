# PremiseReplayPlugin

## Overview

SwiftPM command plugin for inspecting replay traces.

---

## Interface

- `swift package premise-replay` invokes `PremiseReplayTool` with the supplied arguments.

---

## Invariants

- The plugin waits for the tool and reports an error if it does not exit successfully.

---

## Side Effects

- Launches a subprocess and forwards its arguments; the tool may read files and writes to standard streams.

---

## Verification

- From the repository root, run `swift test`.
