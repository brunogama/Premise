# PremiseDatabase

## Overview

Persistence and replay support for property-test failures.

---

## Interface

- `ExampleDatabase` is the actor-based storage boundary: `loadTraces`, `save`, and `clear`.
- File-backed, SQLite-backed, and composite implementations and replay/persistence codecs are provided in this directory.
- `ReplayFirstExecutor` loads persisted traces before fresh generation and saves failures; `FailureTraceExporter` exports trace artifacts.

### Migrating persisted failure record construction

`PersistedFailureRecordV1` now takes `recordFormatVersion` and
`traceFormatVersion` after all required arguments and before `seed`. Callers
that specify either version must move those arguments to that position. This
is a source-breaking signature change. The default versions and persisted
format are unchanged.

---

## Invariants

- Database operations are asynchronous and may throw; records and traces are keyed by `PropertyIdentity`.

---

## Side Effects

- Storage implementations read, write, and clear persisted failure data; the SQLite implementation accesses a database.
- Trace export creates destination directories and writes JSON artifacts atomically.

---

## Verification

- From the repository root, run `swift test`.
