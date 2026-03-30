# Feature Landscape

**Domain:** Swift property-based testing framework
**Project:** Premise
**Researched:** 2026-03-30
**Overall confidence:** HIGH

## Framing

Premise should not try to invent a new testing culture for Swift. The target
user already lives in `swift-testing` and XCTest, expects async-safe tests,
actionable failure output, and one-step reproduction of flaky counterexamples.
Modern property-based tools in neighboring ecosystems add two strong
expectations on top of that baseline: shrinking is automatic, and failures are
replayable across runs.

The fixed ARD matters here. Premise is not a generic "maybe later" property
testing library; v1 is explicitly engine-first, replay-centric, and file-backed.
That means some features that are optional elsewhere become table stakes for
Premise because they are part of the product promise, not just nice extras.

## Table Stakes

Features users will reasonably expect from Premise v1. Missing any of these
would make the framework feel unfinished for senior Swift engineers.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Thin adapters for `swift-testing` and XCTest | Swift developers expect to run tests inside the standard runners they already use. `swift-testing` emphasizes traits, tags, parameterized tests, async/throws support, and parallel execution; XCTest compatibility still matters for incremental adoption. | Med | Must stay adapter-thin so `PremiseCore` remains isolated. Property-level config should map naturally onto `swift-testing` traits and XCTest helpers. |
| Async/throws-friendly authoring under Swift 6 strict concurrency | `swift-testing` examples are `async throws`, and tests run in parallel by default. Premise users will expect property closures and adapters to compile cleanly under strict concurrency. | High | This is both a product expectation and a hard project constraint. It is a v1 requirement, not a future enhancement. |
| Composable strategy library for common Swift types | SwiftCheck and modern Swift 6 alternatives both center their API on built-in generators plus composition. Users expect numbers, strings, collections, optionals, enums, and other standard shapes to be available immediately. | High | The public API should prioritize witness/provider-based composition over one-off special cases. Custom domain types must be first-class, not an afterthought. |
| Edge-case-aware generation for standard domains | Hypothesis and jqwik both treat boundary values as first-class because pure random generation misses real bugs. Users expect empty collections, zero, bounds, and other canonical edge cases to appear without hand-rolling them every time. | Med | Keep edge-case injection deterministic and configurable. This belongs in the standard strategies layer, not in ad hoc test helpers. |
| Automatic shrinking to a minimal counterexample | Shrinking is baseline behavior in SwiftCheck, PropertyBased, jqwik, Proptest, and Hypothesis. Modern users assume failures come back minimized. | High | Premise cannot ship v1 with "generated a big failing blob, now debug it yourself." Structural shrinking is one of the core product claims. |
| Deterministic replay of failures | PropertyBased exposes fixed seeds, jqwik reruns with previous seed, and Hypothesis/Proptest replay prior failures. Once a property fails, users expect a direct path to re-running it. | Med | Failure output should always include a stable reproduction handle. In Premise that should be trace-first, not just RNG-state-first. |
| Local failure persistence with replay-before-generate behavior | Hypothesis persists examples in an example database and Proptest stores regression cases in source-adjacent files. For Premise specifically, file-backed failure persistence is part of the v1 promise, so it is table stakes. | Med | Persist locally, replay before fresh exploration, and keep the format inspectable enough for developers to trust it. |
| Per-property execution controls | Mature tools expose knobs for case count, shrinking behavior, seeds, time budgets, and related settings. Swift users will also expect this to compose with trait-driven test configuration. | Med | Start with the smallest useful set: cases, replay source, persistence policy, shrink mode, and maybe time budget. Avoid a sprawling configuration matrix in v1. |
| Actionable failure diagnostics | Swift Testing already raises the bar with captured values in `#expect`. Property frameworks must add failing input, minimal input, replay instructions, and enough run context to explain what happened. | Med | Good failure output is part of the product, not polish. Include original and shrunk cases when useful, plus discard/run counts where they explain behavior. |
| Assumptions/filtering with discard accounting | Real properties need constraints, but discarded-case explosions silently weaken tests. SwiftCheck uses implication; jqwik and Hypothesis both document the cost of bad filters and provide guidance or warnings. | Med | Support assumptions, but report discard rates and steer users toward constructive strategies. Silent degradation is unacceptable. |

## Differentiators

Useful features that can make Premise meaningfully better than the current
Swift baseline, but are not required to make v1 credible.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Stable, versioned trace and failure-record formats | Hypothesis explicitly warns that its example database can be invalidated by upgrades or test-shape changes. Proptest’s seed persistence is robust, but not exact if strategy behavior changes. Premise can differentiate by making replay artifacts durable and migration-aware. | High | This aligns directly with the ARD and should be treated as a strategic advantage, even if v1 keeps the first format simple. |
| Structural shrinking that works for composed custom strategies without bespoke shrinkers | Existing frameworks often rely on per-generator shrink behavior or generator-specific APIs. Premise’s choice-trace model can make shrinking feel more uniform and less hand-authored. | High | This is the most important technical differentiator because it improves everyday ergonomics without expanding the surface area much. |
| Telemetry hooks and distribution introspection | jqwik exposes statistics collection; Hypothesis exposes health checks, verbosity, and targeted metrics. Premise can expose engine events without hard-coding a single reporter UX. | Med | Good fit for v2. Start with hooks, not dashboards. |
| Coverage-guided or target-guided exploration | Hypothesis exposes `target()` and recommends coverage-guided fuzzing for high-example-count workloads. Bringing guided exploration to Swift would be a real differentiator. | High | Valuable, but not necessary to validate Premise’s core proposition. v2 feature. |
| Parallel property execution with deterministic corpus coordination | `swift-testing` runs tests in parallel by default, but most PBT frameworks do not make shared, replayable persistence across parallel workers a headline feature. | High | Requires concurrency-safe persistence and careful artifact ownership. This belongs after single-run determinism is solid. |
| Optional SMT-backed provider for constrained domains | Very few mainstream property-testing tools offer solver-backed generation as an extension. This would be a powerful differentiator for protocol, parser, and validation-heavy domains. | High | Separate research topic. Keep it explicitly optional so v1 users never pay the complexity tax. |
| Small-domain exhaustive mode or advanced edge-case scheduling | jqwik can exhaustively enumerate small domains and drive edge-case-first runs. This is useful, but not the first thing Swift users need from Premise. | Med | Worth considering after the base strategy and replay story is stable. |

## Anti-Features

Features to explicitly not build in Premise v1, either because they fight the
fixed ARD or because they create too much surface area before the core engine is
proven.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Full stateful/model-based testing DSL in v1 | jqwik, Proptest, and Hypothesis all support some form of stateful testing, but it is materially more complex than single-property generation and replay. Shipping it early would dilute focus and destabilize the core trace model. | Nail single-step properties, replay, shrinking, and persistence first. Leave a clean extension seam for operation-sequence testing later. |
| Remote or network-backed failure storage | The project scope explicitly keeps persistence local in v1 and local/SQLite in v2. Remote backends add auth, sync, conflict, and privacy problems that do not help validate the engine. | Use local files in v1. If cross-machine sharing matters, lean on checked-in artifacts or CI artifacts before inventing a service. |
| A bespoke assertion DSL or macro-heavy test language | Swift developers already have `#expect`, `#require`, and XCTest assertions. Replacing those would create unnecessary adoption friction. | Integrate with the existing assertion surfaces and focus innovation on input generation, shrinking, replay, and persistence. |
| Huge batteries-included domain packs in the initial release | Hypothesis has many extras and integrations because it is mature. Premise is greenfield. Chasing broad integrations early would create maintenance drag before the engine is battle-tested. | Ship a strong core strategies layer plus extension points for domain-specific packages. |
| Blob-only or unstable replay artifacts | Hypothesis’ `@reproduce_failure` blob is intentionally temporary and version-sensitive. That is useful for CI, but not a good sole replay mechanism for Premise. | Prefer human-trackable, versioned trace/failure artifacts. Temporary opaque handles can exist, but must not be the only replay path. |
| Full external fuzzer orchestration in v1 | Hypothesis has a guide for using an external fuzzer and recommends it for very high-example-count scenarios. That is valuable, but it is a separate product problem from delivering a strong Swift-native PBT framework. | Keep v1 focused on deterministic property testing. Revisit external fuzzing only after telemetry and guided exploration land. |

## Feature Dependencies

```text
Runner adapters + property-level config
  -> usable Swift authoring experience

Strategy library + edge-case-aware generation
  -> practical input space coverage

Strategy library
  -> shrinking
  -> replay

Shrinking + replay
  -> actionable diagnostics

Replay
  -> local failure persistence
  -> future stable trace format

Stable trace/failure format
  -> SQLite persistence
  -> parallel execution coordination
  -> coverage-guided exploration
  -> optional SMT-backed provider

Strict-concurrency-safe core
  -> reliable `swift-testing` integration
  -> future parallel property execution
```

## MVP Recommendation

Prioritize:

1. `swift-testing` and XCTest adapters with async/throws-safe authoring and a
   small, trait-friendly configuration surface.
2. A strong standard strategy library with edge-case-aware generation and an
   ergonomic custom strategy story.
3. Automatic shrinking plus deterministic replay that is always exposed in
   failure output.
4. File-backed local failure persistence that replays saved failures before
   fresh exploration.

Defer:

- Coverage-guided exploration: powerful, but it is a second-order optimizer for
  a framework whose first-order job is deterministic counterexample discovery.
- Telemetry dashboards or fixed reporting UIs: hooks first, opinionated tooling
  later.
- Stateful/model-based testing DSL: real value, wrong first release.
- SMT-backed providers: promising extension, not part of the v1 adoption wedge.
- Remote corpus sharing: out of scope for the current product definition.

## Sources

Primary and official sources used for classification:

- Swift Testing official repository README: <https://github.com/swiftlang/swift-testing>
- SwiftCheck official repository README: <https://github.com/typelift/SwiftCheck>
- PropertyBased for Swift 6 official repository README: <https://github.com/x-sheep/swift-property-based>
- Hypothesis documentation index: <https://hypothesis.readthedocs.io/en/latest/>
- Hypothesis replaying failures: <https://hypothesis.readthedocs.io/en/latest/tutorial/replaying-failures.html>
- Hypothesis API reference (`target`, settings, database, verbosity): <https://hypothesis.readthedocs.io/en/latest/reference/api.html>
- Hypothesis health checks: <https://hypothesis.readthedocs.io/en/latest/how-to/suppress-healthchecks.html>
- jqwik current user guide: <https://jqwik.net/docs/current/user-guide>
- Proptest introduction: <https://proptest-rs.github.io/proptest/>
- Proptest failure persistence: <https://proptest-rs.github.io/proptest/proptest/failure-persistence.html>
- Proptest test runner: <https://proptest-rs.github.io/proptest/proptest/tutorial/test-runner.html>
- Proptest state machine testing: <https://proptest-rs.github.io/proptest/proptest/state-machine.html>

Confidence notes:

- HIGH: Shrinking, replay, strategy composition, standard-runner integration,
  and local persistence are all reinforced by multiple primary sources.
- MEDIUM: Exhaustive generation and advanced statistics are strong adjacent
  signals, but not yet clear Swift-specific expectations for v1.
- HIGH: Stateful/model-based testing is valuable in mature ecosystems, but the
  cost and surface-area expansion make it the wrong Premise v1 target.
