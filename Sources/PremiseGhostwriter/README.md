# PremiseGhostwriter

## Overview

Renders Swift property-test skeletons for common testing patterns.

---

## Interface

- `GhostwriterTemplateKind`, `GhostwriterRequest`, `GhostwriterError`, and `PremiseGhostwriter.render` define the rendering API.
- Typed helpers cover fuzzing, round trips, equivalence, idempotence, and binary-operation laws.
- The throwing typed helpers require `try`; callers migrating from their earlier nonthrowing signatures must handle `GhostwriterError`.

---

## Invariants

- `render`, `roundtrip`, `equivalence`, `idempotence`, and `binaryOperationLaws` throw `GhostwriterError` for missing required template expressions. `fuzzNoCrash` remains nonthrowing.
- Rendered output is a skeleton and still requires the caller to supply meaningful expressions and tests.

---

## Side Effects

- Rendering returns generated Swift source as a string; it does not itself write files.

---

## Verification

- From the repository root, run `swift test`.
