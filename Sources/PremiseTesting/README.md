# PremiseTesting

## Overview

Swift Testing integration for Premise property tests and stateful test patterns.

---

## Interface

- `forAll` provides synchronous and asynchronous property-closure overloads backed by the Premise runner.
- Variadic parameter-pack overloads support any number of typed strategies for synchronous or asynchronous properties; existing one-, two-, and three-strategy overloads remain available.
- Variadic strategy combinations shrink via recorded choice traces rather than component-level value shrinkers.
- `expectForAll` adapts Boolean predicates; `checkOperationSequence`, `checkRuleBasedStateMachine`, and `checkStateMachine` provide stateful test entry points.
- `expectRoundTrip` and `expectModelAgreement` provide common property patterns.

---

## Invariants

- The Swift Testing integration is compiled only when the `Testing` module is available.
- The `forAll` adapter uses replay-first execution and reports minimized failures as Swift Testing issues.

---

## Side Effects

- Executes caller properties, reports test issues, and uses a file-backed database for replay and failures.

---

## Verification

- From the repository root, run `swift test`.
