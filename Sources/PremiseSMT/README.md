# PremiseSMT

## Overview

SMT-related interfaces, including a pseudo-random primitive provider and a separate optional Z3 context.

---

## Interface

- `PremiseSMTModule` identifies the module; `SMTProvider` implements the `PrimitiveProvider` boundary.
- Z3 availability, context, and version-policy sources support the solver integration.

---

## Invariants

- `SMTProvider` delegates all primitive bit and byte draws to a pseudorandom provider, including when the SMT trait is enabled.
- The Z3 context is trait-gated and requires the Z3 library; it is separate from `SMTProvider`.

---

## Side Effects

- Primitive draws mutate provider state; solver-backed paths may allocate and release Z3 resources.

---

## Verification

- From the repository root, run `swift test`; the SMT-enabled configuration additionally requires Z3.
