# PremiseMacrosPlugin

## Overview

Compiler plugin implementing the `@given` peer macro.

---

## Interface

- `GivenMacro.expansion` produces the peer declaration; the compiler plugin registers `GivenMacro`.

---

## Invariants

- Expansion requires a function declaration with a body and matching strategy and function-parameter counts.
- Configuration and example labels are separated from strategy arguments before the arity check.
- Expansion constructs SwiftSyntax nodes directly and combines four or more strategies with variadic `zip`.

---

## Side Effects

- Expansion creates Swift syntax consumed by the compiler; generated tests execute property code when run.

---

## Verification

- From the repository root, run `swift test`.
- This retained source is not built by the package in this version.
- With a local SwiftSyntax checkout available, run `bash scripts/test-macro-regression.sh` to exercise expansion and Swift Testing discovery in an isolated consumer.
