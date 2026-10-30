# Plugins

## Overview

SwiftPM command plugins delegate to the corresponding executable targets.

---

## Interface

- [PremiseGhostwriterPlugin](./PremiseGhostwriterPlugin/README.md) generates property-test skeletons.
- [PremiseReplayPlugin](./PremiseReplayPlugin/README.md) inspects replay traces.

---

## Invariants

- Each plugin forwards arguments and reports unsuccessful tool execution.

---

## Side Effects

- Plugins launch subprocesses; their tools use standard streams and may read files.

---

## Verification

- From the repository root, run `swift test`.
