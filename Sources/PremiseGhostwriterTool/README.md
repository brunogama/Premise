# PremiseGhostwriterTool

## Overview

Command-line entry point for generating property-test skeletons.

---

## Interface

- `swift package premise-ghostwriter --help` displays supported template kinds and options.
- The executable builds a `GhostwriterRequest` and passes it to `PremiseGhostwriter.render`.

---

## Invariants

- Required options and template-specific expressions must be supplied. Option tokens cannot be used as the value of a preceding option.

---

## Side Effects

- Writes generated source or help to standard output; errors go to standard error and exit with status 1.

---

## Verification

- From the repository root, run `swift test`.
