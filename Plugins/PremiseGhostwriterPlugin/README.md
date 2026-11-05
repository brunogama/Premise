# PremiseGhostwriterPlugin

## Overview

SwiftPM command plugin for generating property-test skeletons.

---

## Interface

- `swift package premise-ghostwriter` invokes `PremiseGhostwriterTool` with the supplied arguments.

---

## Invariants

- The plugin waits for the tool and reports an error if it does not exit successfully.

---

## Side Effects

- Launches a subprocess and forwards its arguments; the tool uses standard output and standard error.

---

## Verification

- From the repository root, run `swift test`.
