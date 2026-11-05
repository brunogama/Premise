# PremiseXCTest

## Overview

XCTest adapter for Premise property tests.

---

## Interface

- `premise_forAll` offers synchronous and asynchronous property-closure overloads and supports explicit examples.

---

## Invariants

- The adapter is compiled only when XCTest can be imported.
- Failures are reported through `XCTFail` at the caller's source location with minimized failure information.

---

## Side Effects

- Executes caller properties, reports XCTest failures, and uses a file-backed database for replay and failure persistence.

---

## Verification

- From the repository root, run `swift test`.
