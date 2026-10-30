# PremiseStrategies

## Overview

Standard value-generation strategies, composition operators, and builders on top of PremiseCore.

---

## Interface

- `StrategyBuilder`, `WeightedStrategy`, `WeightedStrategyBuilder`, `buildStrategy`, and `buildWeightedStrategy` compose strategies.
- Numeric, collection, Foundation, vector, catalog, and standard strategy implementations live in this module.

---

## Invariants

- `StrategyBuilder` requires at least one component when building a block or array.
- Weighted composition delegates to the strategy frequency combinator.

---

## Side Effects

- Builders construct strategy values; drawing from a strategy consumes and mutates the supplied generation state.

---

## Verification

- From the repository root, run `swift test`.
