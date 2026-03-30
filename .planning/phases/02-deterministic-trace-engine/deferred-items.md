# Deferred Items

## 2026-03-30

- Full-repo `swiftlint lint --strict --config .swiftlint.yml` fails on unrelated
  future-phase test files already present in the worktree but outside plan
  `02-01` scope:
  - `Tests/ConjectureStrategiesTests/StrategyCompositionTests.swift`
    - `multiline_function_chains`
  - `Tests/ConjectureStrategiesTests/RecursiveStrategyTests.swift`
    - `prefer_self_in_static_references`
  - `Tests/ConjectureCoreTests/EndToEndShrinkingTests.swift`
    - `line_length`
  - `Tests/ConjectureCoreTests/StructuralShrinkingTests.swift`
    - `line_length`
  - `Tests/ConjectureCoreTests/RunnerFailureTests.swift`
    - `line_length`
  - `Tests/ConjectureCoreTests/RunnerReplayTests.swift`
    - `line_length`
