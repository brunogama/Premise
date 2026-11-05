# CZ3

## Overview

C system-module boundary for the Z3 solver.

---

## Interface

- `cz3.h` includes the installed Z3 C header; `module.modulemap` defines the Swift import boundary.

---

## Invariants

- Consumers need an available Z3 header and library when building the Z3-backed configuration.

---

## Side Effects

- This wrapper header declares no operations of its own; Z3 calls made by consumers may allocate solver resources.

---

## Verification

- From the repository root, run `swift test`; Z3-enabled configurations additionally require Z3.
