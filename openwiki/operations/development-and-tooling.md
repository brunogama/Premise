---
type: operations
title: Development and tooling
description: SwiftPM products, optional traits, developer validation, and command tools in Premise.
tags: [swiftpm, tooling, testing]
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

# Development and tooling

Premise requires Swift tools 6.2. Its manifest declares libraries including Core, Strategies, Database, Testing, XCTest, Fuzzing, Parallel, Telemetry, and CoverageGuided, plus ghostwriter and replay executables. The default trait set is empty; `CoverageGuided`, `Telemetry`, and `SMT` are opt-in traits. Testing and XCTest adapters both depend on Core, Strategies, and Database.

## Local checks

The README documents `swift build`, `swift test`, and `bash scripts/validate-boundaries.sh` for local verification. It also instructs contributors to run `bash scripts/test-macro-exclusion.sh` to verify macro exclusion. Consult `RULES.md` and current CI configuration for the applicable full gate rather than treating these commands as an exhaustive substitute.

## Command tools

The manifest defines the `premise-ghostwriter` command plugin for generating property-test skeletons. The README documents the `premise-replay` command for inspecting a persisted trace artifact or reproduction blob. See [Failure persistence and replay](../workflows/replay-and-persistence.md) for trace formats and replay behavior.

Start at the [documentation map](../quickstart.md) for links to execution and testing concepts.
