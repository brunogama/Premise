# PremiseMacros

## Overview

Public macro declaration for property tests.

---

## Interface

- `@given(_:)` attaches a generated Swift Testing peer around a function using the supplied strategies.

---

## Invariants

- The number of strategy arguments must match the annotated function's parameters; optional configuration and example arguments are supported.
- Four or more strategies are combined with variadic `zip` before calling `forAll`; its pack-based strategy uses trace-based shrinking.

---

## Side Effects

- Macro expansion generates a test declaration at compile time; the resulting test invokes the property engine at runtime.

---

## Verification

- From the repository root, run `swift test`.
- This retained source is not built by the package in this version.
- With a local SwiftSyntax checkout available, run `bash scripts/test-macro-regression.sh` to build the retained macro in an isolated consumer.
