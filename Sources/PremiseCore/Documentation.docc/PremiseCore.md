# ``PremiseCore``

The deterministic choice-trace engine at the heart of the Premise property-based testing framework.

## Overview

Premise is a Swift-native property-based testing framework. Instead of writing individual hand-crafted examples, you describe *properties* — invariants that must hold for any input — and let the engine generate hundreds of cases automatically.

When a case fails, Premise captures the exact sequence of random choices that led to it (the *choice trace*), shrinks that trace to the smallest possible failing input, and saves it to disk so it is replayed deterministically on every future run.

``PremiseCore`` contains the primitive engine types:

- **``PremiseData``** — the interface a strategy uses to draw random values during a single run
- **``ChoiceTrace``** — the record of every draw decision made during a run
- **``Strategy``** — the witness type that knows how to generate and shrink a value
- **``Runner``** — executes a property against many generated inputs and invokes the shrink machine on failure
- **``ShrinkMachine``** — minimises a failing trace by systematically trying smaller alternatives
- **``PropertyConfig``** — per-property execution knobs (run count, shrink budget, seed, draw budget)
- **``FailureRecord``** — a persisted record of a minimised counterexample

The framework adapters (`PremiseTesting` for swift-testing, `PremiseXCTest` for XCTest) wrap these types. You normally interact with ``PremiseCore`` directly only when writing custom strategies or extending the engine.

## Topics

### Getting Started

- <doc:WhyPropertyTesting>
- <doc:HowTheEngineWorks>
- <doc:StrategyCatalog>
- <doc:GivenMacroAndConfiguration>

### Core Types

- ``PremiseData``
- ``Strategy``
- ``Runner``
- ``RunResult``
- ``PropertyConfig``
- ``PropertyIdentity``
- ``ChoiceTrace``
- ``ShrinkMachine``
- ``FailureRecord``
- ``PrimitiveProvider``
- ``PseudoRandomProvider``
- ``ReplayProvider``

### Writing Properties

- <doc:CustomStrategies>
- <doc:AdvancedCombinators>
- <doc:ShrinkingExplained>

### Persistence and Replay

- <doc:FailurePersistenceAndReplay>

### Advanced

- <doc:ParallelTesting>
- <doc:TelemetryAndObservability>
- <doc:SwiftConcurrencySafety>

### Tutorials

- <doc:Premise>
