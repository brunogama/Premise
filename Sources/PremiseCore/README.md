# PremiseCore

## Overview

Core property-test engine types, strategies, choice traces, providers, execution, and shrinking.

---

## Interface

- `PremiseCoreModule`, `FailureRecord`, `FailureTraceArtifact`, and `FailureDiscovery` define the core marker and failure envelopes.
- `Strategy`, `PrimitiveProvider`, `PremiseData`, `Runner`, `PropertyConfig`, `ChoiceTrace`, and run result types form the generation and execution boundary.
- `PropertyIdentity`, `ExplicitExample`, `PseudoRandomProvider`, and `ReplayProvider` identify and supply runs; `ShrinkMachine` and `AsyncShrinkMachine` minimize failures.

---

## Invariants

- `FailureRecord` carries the identity and canonical trace needed to replay a minimized failure.
- Decoding older failure records supplies defaults for subsequently added fields.

---

## Side Effects

- Execution invokes caller-provided property and strategy closures; providers and run state mutate during draws.
- Failure records capture a timestamp by default.

---

## Verification

- From the repository root, run `swift test`.
