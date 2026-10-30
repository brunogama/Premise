# Sources

## Overview

Production targets for Premise's property-testing engine, integrations, tools, and optional native dependencies.

---

## Interface

- [PremiseCore](./PremiseCore/README.md): core generation, execution, and failure types.
- [PremiseStrategies](./PremiseStrategies/README.md): reusable strategies and combinators.
- [PremiseDatabase](./PremiseDatabase/README.md): failure storage and replay.
- [PremiseTesting](./PremiseTesting/README.md) and [PremiseXCTest](./PremiseXCTest/README.md): test-framework adapters.
- [PremiseParallel](./PremiseParallel/README.md): deterministic parallel runner.
- [PremiseCoverageGuided](./PremiseCoverageGuided/README.md) and [CPremiseSanitizerCoverage](./CPremiseSanitizerCoverage/README.md): coverage guidance and native callbacks.
- [PremiseFuzzing](./PremiseFuzzing/README.md): byte-oriented fuzzer bridge.
- [PremiseTelemetry](./PremiseTelemetry/README.md): event observation.
- [PremiseGhostwriter](./PremiseGhostwriter/README.md), [PremiseGhostwriterTool](./PremiseGhostwriterTool/README.md), and [PremiseReplayTool](./PremiseReplayTool/README.md): generation and replay tools.
- [PremiseMacros](./PremiseMacros/README.md) and [PremiseMacrosPlugin](./PremiseMacrosPlugin/README.md): retained experimental macro sources, not included in this version.
- [PremiseSMT](./PremiseSMT/README.md) and [CZ3](./CZ3/README.md): optional SMT and Z3 boundary.

---

## Invariants

- Core choice traces and failure records provide replay information across engine and persistence boundaries.
- Optional integrations retain their respective compile-time and native dependency requirements.

---

## Side Effects

- Executing properties invokes caller code and may persist failures; tools use standard streams and may read files.
- Native coverage, telemetry sinks, and optional solver integrations can affect process state or external resources.

---

## Verification

- From the repository root, run `swift test`.
- Verify the macro is excluded with `bash scripts/test-macro-exclusion.sh`.
