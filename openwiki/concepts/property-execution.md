---
type: architecture
title: Property execution and shrinking
description: How Premise runs generated cases, records choices, and minimizes reproducible failures.
tags: [execution, replay, shrinking]
verified:
  - by: openwiki/0.7.2
    at: 2026-11-01T12:35:26.822Z
sources:
  - id: openwiki-source-e556407bb54ae7e04017cda9
    resource: repo://Sources/PremiseCore/ChoiceTrace.swift
  - id: openwiki-source-be560462eeaec75ca2dc21d3
    resource: repo://Sources/PremiseCore/Runner.swift
  - id: openwiki-source-900b8cbdfb04bee656cd96be
    resource: repo://Sources/PremiseCore/Runner%2BExecution.swift
  - id: openwiki-source-95b9f32d57272b484ec5bdd3
    resource: repo://Sources/PremiseCore/Runner%2BMinimization.swift
generated: { by: "pi", at: "2026-11-01T12:35:26.822Z" }
---

# Property execution and shrinking

`Runner<Value>` combines a strategy, a `PropertyConfig`, and a property identity. Its detailed entry points walk the configured phases, collecting a report and returning when a phase finds a failure. The runner accepts ordinary, data-aware, and asynchronous property closures.

## Attempts and replay

An attempt draws a value using its primitive provider and then invokes the property. A draw error or `PremiseRejection` is a rejection; another thrown error is a failure. A configured deadline may also turn a completed property into a failure. Replay uses a `ReplayProvider` initialized with a stored `ChoiceTrace` to repeat primitive choices.

`ChoiceTrace` records entries and spans. It supports a versioned binary representation with the `PTRC` magic header and copy-paste reproduction blobs prefixed `premise-trace-v1:`. This represents choices rather than an arbitrary serialized Swift value.

## Minimization

When a failure is processed, the runner checks reproducibility through the shrink session. If the configured phases do not include shrinking, it returns an unshrunk failure; otherwise, the session minimizes the failure. Separate overloads handle synchronous, data-aware, and asynchronous properties. The replay tests exercise a failure, replay its trace, and check that the replayed failure retains both trace and value.

See [Strategies and test integrations](../workflows/strategies-and-testing.md) for the caller-facing interface and [Failure persistence and replay](../workflows/replay-and-persistence.md) for stored failures.
