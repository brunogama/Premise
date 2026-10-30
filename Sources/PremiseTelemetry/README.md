# PremiseTelemetry

## Overview

Observation boundary for engine lifecycle events.

---

## Interface

- `EngineEvent` represents events; `TelemetrySink.record` receives them asynchronously.
- `TelemetryRelay` registers sinks and emits events to them.

---

## Invariants

- Sinks must not mutate engine traces, configurations, or results.
- The relay forwards an event to registered sinks in registration order; an empty relay returns immediately.

---

## Side Effects

- Registering mutates actor-isolated relay state; emitting invokes sink implementations, which may record events externally.

---

## Verification

- From the repository root, run `swift test`.
