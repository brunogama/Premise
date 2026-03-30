# Deferred Items

## 2026-03-30

- Full-repo `swiftlint lint --strict --config .swiftlint.yml` fails on unrelated
  future-phase test files already present in the worktree but outside plan
  `02-01` scope:
  - `Tests/PremiseStrategiesTests/StrategyCompositionTests.swift`
    - `multiline_function_chains`
  - `Tests/PremiseStrategiesTests/RecursiveStrategyTests.swift`
    - `prefer_self_in_static_references`
  - `Tests/PremiseCoreTests/EndToEndShrinkingTests.swift`
    - `line_length`
  - `Tests/PremiseCoreTests/StructuralShrinkingTests.swift`
    - `line_length`
  - `Tests/PremiseCoreTests/RunnerFailureTests.swift`
    - `line_length`
  - `Tests/PremiseCoreTests/RunnerReplayTests.swift`
    - `line_length`
