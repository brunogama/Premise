---
type: overview
title: Premise documentation map
description: Starting points for understanding and using the Swift Premise property-testing package.
tags: [overview, navigation, property-testing]
verified:
  - by: openwiki/0.7.2
    at: 2026-11-01T12:35:26.822Z
sources:
  - id: openwiki-source-16a6a536c0a5303df5e05c6c
    resource: repo://Package.swift
  - id: openwiki-source-23775c3de52f3ab95a13cb8b
    resource: repo://README.md
generated: { by: "pi", at: "2026-11-01T12:35:26.822Z" }
---

# Premise documentation map

Swift Premise is a Swift property-based testing framework. It generates inputs from strategies, searches for smaller counterexamples, and supports reproducible failure traces. The SwiftPM manifest exposes separate libraries for core execution, strategies, persistence, test-framework adapters, and related tooling.

## Choose a path

- [Strategies and test integrations](workflows/strategies-and-testing.md) explains generated values, composition, Swift Testing and XCTest adapters, and stateful properties.
- [Property execution and shrinking](concepts/property-execution.md) follows attempts, trace recording, replay, and minimization.
- [Failure persistence and replay](workflows/replay-and-persistence.md) describes replay-first execution, file and SQLite stores, and trace inspection.
- [Development and tooling](operations/development-and-tooling.md) covers package products, traits, commands, and local verification.

For installation, supported platforms, and a first runnable property, start with the repository [README](../README.md).
