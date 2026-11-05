---
type: workflow
title: Strategies and test integrations
description: How strategies produce and shrink inputs and how test adapters and state machines run properties.
tags: [strategies, testing, state-machines]
verified:
  - by: openwiki/0.7.2
    at: 2026-11-01T12:35:26.822Z
sources:
  - id: openwiki-source-d707895841a1da38526d7f3b
    resource: repo://Sources/PremiseStrategies/Zip/StrategyTripleZip.swift
  - id: openwiki-source-2d50a41cfd317a7b2d1ab4a9
    resource: repo://Sources/PremiseTesting/ForAll.swift
  - id: openwiki-source-c766dc58952742a54b4e70a7
    resource: repo://Sources/PremiseTesting/RuleBasedStateMachine.swift
  - id: openwiki-source-9af5bfa4cc1ae6b5d70b539b
    resource: repo://Sources/PremiseXCTest/Compatibility/PremiseForAllCompatibility.swift
  - id: openwiki-source-cdea65c051e417786fcb2df2
    resource: repo://Tests/PremiseTestingIntegrationTests/TripleStrategyContractTests.swift
generated: { by: "pi", at: "2026-11-01T12:35:26.822Z" }
---

# Strategies and test integrations

A strategy supplies generation and shrinking behavior to the property runner. Strategies can be combined: the three-strategy `zip` draws in argument order and constructs shrink candidates by shrinking one tuple component at a time. The triple-strategy contract test checks labels, draw order, and shrink order.

## Test framework adapters

Swift Testing callers use `forAll`, which accepts a strategy, configuration, explicit examples, and a property closure. It builds a runner and uses replay-first execution backed by a file database; failures are reported as Swift Testing issues. Both synchronous and asynchronous property closures are supported.

XCTest callers use `premise_forAll`. Its adapter likewise constructs a runner and replay-first executor and reports failures at the caller's source location through XCTest. The adapter is conditional on XCTest being available.

## Stateful properties

`checkRuleBasedStateMachine` constructs a state-machine runner with its machine, configuration, optional file database, and either the configured seed or a random seed. State construction and rule precondition failures are wrapped with run metadata and phase context. The README shows registration of rules and invariants for model-based testing.

See [Property execution and shrinking](../concepts/property-execution.md) and [Failure persistence and replay](replay-and-persistence.md) for execution and persistence details.
