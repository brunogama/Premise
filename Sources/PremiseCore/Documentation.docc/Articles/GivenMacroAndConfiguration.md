# @given Macro and Configuration

Eliminate boilerplate with the `@given` macro and configure test runs with `PropertyConfig` presets.

## Overview

Premise is inspired by Python's Hypothesis, and the `@given` macro mirrors Hypothesis's `@given` decorator: you declare strategies inline, and the framework generates the test harness for you. This article covers the macro, multi-arity `forAll` overloads, `PropertyConfig` presets, and chainable builders.

## The @given Macro

Import `PremiseMacros` alongside `PremiseTesting` to use the `@given` decorator:

```swift
import PremiseMacros
import PremiseTesting
import PremiseStrategies

@given(.integers(in: 0...100), .ascii)
func additionIsCommutative(a: Int, s: String) {
    #expect(a + s.count >= a)
}
```

This expands to:

```swift
@Test func additionIsCommutative() async throws {
    try await forAll(.integers(in: 0...100), .ascii) { a, s in
        #expect(a + s.count >= a)
    }
}
```

The number of strategy arguments must match the number of function parameters. The macro validates this at compile time and emits a clear error if there's a mismatch.

### Passing Configuration

Add a `config:` labeled argument as the last parameter:

```swift
@given(.integers(in: 0...100), config: .thorough)
func largeSearchSpace(n: Int) {
    #expect(n * 2 / 2 == n)
}
```

### Why @given and Not @Property?

Hypothesis uses `@given` because the decorator says "given these data generators, run the test body with generated values." It does not imply the function is a mathematical property — just that it receives generated inputs. The name `@Property` is QuickCheck heritage; Premise follows the Hypothesis convention.

## Multi-Arity forAll

For cases where you don't want the macro, Premise provides 2-ary and 3-ary `forAll` overloads that handle value-level shrinking on each component:

```swift
// 2 strategies
try await forAll(.integers(in: 0...100), .ascii) { n, s in
    #expect(s.count >= 0)
}

// 3 strategies
try await forAll(.integers(in: 0...10), .booleans, .ascii) { n, flag, s in
    // ...
}
```

These overloads shrink each component independently, which produces better minimal counterexamples than a single `zip()`.

## PropertyConfig Presets

Rather than specifying every parameter, use the built-in presets:

```swift
// Fast feedback during development
try await forAll(.integers(in: 0...100), config: .quick) { n in ... }

// Deep exploration for critical paths
try await forAll(.integers(in: 0...100), config: .thorough) { n in ... }

// Balanced for CI pipelines
try await forAll(.integers(in: 0...100), config: .ci) { n in ... }
```

| Preset | Runs | Shrink Iterations | Draw Budget | Timeout |
|---|---|---|---|---|
| `.default` | 100 | 500 | 10,000 | none |
| `.quick` | 20 | 100 | 5,000 | none |
| `.thorough` | 1,000 | 2,000 | 20,000 | none |
| `.ci` | 500 | 1,000 | 10,000 | 60s |

## Chainable Builders

Start from any preset and customize with chainable methods:

```swift
let config = PropertyConfig.default
    .runs(500)
    .seed(42)
    .noShrink()
    .timeout(seconds: 30)
```

Available builders:

```swift
.runs(_ count: Int)             // number of generated test runs
.shrinkIterations(_ count: Int) // max shrink attempts
.noShrink()                     // disables shrinking entirely
.seed(_ seed: UInt64)           // deterministic reproduction
.drawBudget(_ max: Int)         // max draws per single run
.noReplay()                     // skip replaying persisted failures
.timeout(seconds: Double)       // wall-clock deadline
```

## Seed-Based Replay

When a property fails, the failure output includes the seed needed to reproduce it:

```
Premise found a counterexample after 37 runs:
  Value: "hello\0world"
  Seed to reproduce: 8374928374
  Replay: config: PropertyConfig(seed: 8374928374)
```

Paste the seed into your config to get a deterministic reproduction:

```swift
@given(.ascii, config: .default.seed(8374928374))
func reproduceFailure(s: String) {
    // This will produce the exact same counterexample
}
```

## Timeout Support

For long-running properties, set a wall-clock timeout. The runner stops after the deadline and reports the best failure found, or passes if none:

```swift
// Stop after 10 seconds regardless of how many runs completed
try await forAll(.integers(in: Int.min...Int.max), config: .default.timeout(seconds: 10)) { n in
    #expect(someExpensiveOperation(n))
}
```

## Next Steps

- See <doc:StrategyCatalog> for the full list of built-in strategies.
- See <doc:AdvancedCombinators> for composing strategies.
- See <doc:FailurePersistenceAndReplay> for how failures are persisted to disk.
