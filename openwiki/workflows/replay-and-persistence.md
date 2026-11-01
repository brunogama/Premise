---
type: workflow
title: Failure persistence and replay
description: Replay-first execution, file and SQLite failure stores, and trace inspection.
tags: [persistence, replay, failures]
verified:
  - by: openwiki/0.7.2
    at: 2026-11-01T12:35:26.822Z
sources:
  - id: openwiki-source-40d3b20213593aa1421034d8
    resource: repo://Sources/PremiseDatabase/FileBackedDatabase.swift
  - id: openwiki-source-272bd5fd349eb9a52e094af0
    resource: repo://Sources/PremiseDatabase/ReplayFirstExecutor.swift
  - id: openwiki-source-90f3a90ae959a20e1244ff59
    resource: repo://Sources/PremiseDatabase/SQLiteBackedDatabase.swift
  - id: openwiki-source-e7f874544e51ac82628226ff
    resource: repo://Sources/PremiseReplayTool/main.swift
generated: { by: "pi", at: "2026-11-01T12:35:26.822Z" }
---

# Failure persistence and replay

`ReplayFirstExecutor` connects a storage-neutral `Runner` to an `ExampleDatabase`. It loads traces for the runner's property identity, supplies them to the runner, and saves a resulting failure. Database load, save, and trace export errors propagate to the caller.

## Storage choices

`FileBackedDatabase` defaults to `.premise/examples` and writes one JSON file per property identity using atomic file writes. It avoids storing duplicate traces and retains at most the newest 32 records per property.

`SQLiteBackedDatabase` defaults to `.premise/examples.sqlite`. Its actor owns a SQLite connection, records format versions, and loads matching traces ordered by creation time. Opening can fail if the runtime is unsafe for WAL, the database cannot be opened, or schema setup fails.

## Inspect a failure

The `premise-replay` tool accepts trace artifacts, persisted envelopes, raw trace JSON, or a reproduction blob. It can print text or JSON and validates the replay blob header and version. For example:

```sh
swift package premise-replay --blob 'premise-trace-v1:...'
```

The replay-ordering integration tests exercise the persistence-to-runner boundary. See [Property execution and shrinking](../concepts/property-execution.md) for attempt and trace behavior.
