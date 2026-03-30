# Conjecture

`SwiftConjectureEngine` is the host repository for Conjecture, a Swift-native
property-based testing framework built around a deterministic choice-trace
engine. The goal is reproducible failures, structural shrinking, and strict
concurrency safety without pushing avoidable abstraction costs into the hot
path.

## Status

The repository now has its initial SwiftPM scaffold in place.

- The architecture and roadmap still live in `.planning/PROJECT.md`.
- The repository exposes the five v1 library products through `Package.swift`.
- The current code is still Phase 1 scaffolding; runtime behavior lands in later phases.

That means the repository now builds and tests as a package, but the public
modules are still compile-stable placeholders rather than a completed property
testing engine.

## Planned Scope

### V1

- core engine for deterministic choice tracing
- strategy catalog for generators and shrinkers
- file-backed failure persistence and replay
- thin adapters for `swift-testing` and XCTest

### V2

- SQLite WAL-backed persistence
- coverage-guided exploration
- parallel property execution
- optional SMT-backed providers

## Planned Package Layout

- `ConjectureCore`
- `ConjectureStrategies`
- `ConjectureTesting`
- `ConjectureXCTest`
- `ConjectureDatabase`
- additive v2 extension targets for guidance and SMT integration

The default build ships only these five v1 products. v2 capabilities remain
future additive seams rather than default package dependencies.

## Design Constraints

- Swift 6 strict concurrency is a baseline requirement.
- The engine core must stay isolated from test frameworks.
- Hot-path abstractions should remain value-oriented and allocation-light.
- V2 must extend V1 without breaking the V1 API surface.

## What Happens Next

1. Replace Phase 1 placeholders with the real deterministic trace engine seams.
2. Land replay, shrinking, and stable persistence contracts.
3. Fill in the `swift-testing` and XCTest adapters.
4. Expand into the V2 roadmap without resetting the core architecture.

## Validation

Run the current Phase 1 repository gates with:

```bash
bash scripts/validate-boundaries.sh
swift build --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors
swift test --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors
```

## Contributing

See `CONTRIBUTING.md`, `RULES.md`, and `WORKFLOW.md` before opening a PR.

## Security

See `SECURITY.md` for vulnerability reporting instructions.

## License

MIT.
