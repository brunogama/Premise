<div align="center">

# Swift Premise

**Swift-native property-based testing with deterministic replay, structural shrinking, and Swift 6 concurrency safety.**

[![CI](https://img.shields.io/github/actions/workflow/status/brunogama/Premise/ci.yml?style=flat-square&label=CI)](https://github.com/brunogama/Premise/actions)
![Swift](https://img.shields.io/badge/Swift-6.2+-f05138?style=flat-square&logo=swift&logoColor=white)
![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-blue?style=flat-square)
![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS-lightgrey?style=flat-square)

[Get started](#getting-started) • [Features](#features) • [Strategies](#strategies) • [Replay](#replay-and-trace-tooling) • [Stateful testing](#stateful-testing) • [Tooling](#ghostwriter-and-fuzzing)

</div>

Swift Premise is a property-based testing framework for Swift. Describe the
behavior your code must always satisfy, then let Premise generate many inputs,
shrink failures to minimal counterexamples, and replay those failures
repeatably in future runs.

> [!NOTE]
> Premise is inspired by Python's Hypothesis, but the API is intentionally
> Swift-native: value-oriented strategies, `Sendable` public types, async-aware
> adapters, SwiftPM plugins, and an optional macro layer that stays out of the
> default dependency graph.

## Features

- **Deterministic replay** — every failing run records a `ChoiceTrace` that can
  be decoded and replayed exactly.
- **Structural shrinking** — failing choices are minimized at the trace level,
  with strategy-specific shrinkers for common Swift values.
- **Persistent failures** — file-backed and SQLite-backed databases replay known
  failures before fresh generation.
- **Rich strategy catalog** — primitives, collections, URLs, UUIDs, dates,
  regex-shaped strings, network strings, records, vectors, recursive data, and
  more.
- **swift-testing and XCTest adapters** — use `forAll` or `premise_forAll`
  without changing your test framework.
- **Stateful testing** — generate operation sequences or rule-based state
  machine programs with replayable minimal failures.
- **Tooling included** — replay trace inspection, ghostwritten property
  skeletons, JSONL run output, and fuzzer byte-input bridging.
- **Strict concurrency** — built for Swift 6 complete strict-concurrency checks.

## Getting started

### Requirements

- Swift 6.2 or newer
- macOS 13+, iOS 16+, tvOS 16+, watchOS 9+, or visionOS 1+

### Install with SwiftPM

Add the package dependency:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/brunogama/Premise.git", from: "1.0.0"),
]
```

Then add the products you need to your test target:

```swift
.testTarget(
    name: "MyPackageTests",
    dependencies: [
        .product(name: "PremiseTesting", package: "SwiftPremise"),
        .product(name: "PremiseStrategies", package: "SwiftPremise"),
    ]
)
```

For XCTest, use `PremiseXCTest` instead of `PremiseTesting`.

### Your first property

```swift
import Testing
import PremiseStrategies
import PremiseTesting

@Test func additionIsCommutative() async throws {
    try await forAll(
        Strategy<Int>.integers(in: -1_000...1_000),
        Strategy<Int>.integers(in: -1_000...1_000)
    ) { x, y in
        #expect(x + y == y + x)
    }
}
```

The XCTest adapter exposes the same engine through `premise_forAll`:

```swift
import XCTest
import PremiseStrategies
import PremiseXCTest

final class MathTests: XCTestCase {
    func testAdditionIsCommutative() async throws {
        try await premise_forAll(
            Strategy<Int>.integers(in: -1_000...1_000),
            Strategy<Int>.integers(in: -1_000...1_000)
        ) { x, y in
            XCTAssertEqual(x + y, y + x)
        }
    }
}
```

## How it works

1. **Draw** — a strategy asks `PremiseData` for primitive choices.
2. **Record** — every choice is stored in a deterministic `ChoiceTrace`.
3. **Check** — your property runs against the generated value.
4. **Shrink** — on failure, Premise replays smaller traces until the
   counterexample is minimal.
5. **Persist** — the failure is stored and replayed first on the next run.

## Strategies

Strategies are values of type `Strategy<Value>`. They describe how to generate,
replay, and shrink a value.

| Category | Examples |
| --- | --- |
| Primitives | integers, unsigned integers, booleans, floats, bytes, constants |
| Text | ASCII, Unicode, regex-shaped strings, domains, emails, IPv4/IPv6 |
| Foundation | `Date`, `DateComponents`, `Duration`, `TimeZone`, `UUID`, `URL` |
| Collections | arrays, sets, dictionaries, fixed records, unique arrays |
| Composition | `map`, `flatMap`, `filter`, `zip`, `oneOf`, weighted choices |
| Recursive data | deferred and recursive strategies with size controls |
| Numeric domains | `Decimal`, rational numbers, complex numbers, vectors |
| Workflows | ranges, indices, generated functions, index operations |

```swift
let user = Strategy<[String: Int]>.record([
    "id": .integers(in: 1...10_000),
    "age": .integers(in: 0...120),
])

let emails = Strategy<String>.emailAddresses()
let payloads = Strategy<[UInt8]>.bytes(length: 0...512)
```

Create custom strategies directly when your domain needs special structure:

```swift
let positiveEven = Strategy<Int>(
    label: "positiveEven",
    draw: { data in
        let n = data.drawInteger(in: UInt64(1)...UInt64(500))
        return Int(n) * 2
    },
    shrink: { value in
        value > 2 ? [2, value / 2] : []
    }
)
```

See the [strategy catalog](Sources/PremiseCore/Documentation.docc/Articles/StrategyCatalog.md)
for the full built-in reference.

## Configuration

Use presets for common test budgets, or customize a run with builder-style
configuration:

```swift
let config = PropertyConfig.ci
    .runs(500)
    .seed(42)
    .deadline(seconds: 0.2)
    .derandomize()
    .printingReproductionBlob()
    .exportingFailureTraces(to: URL(fileURLWithPath: ".premise/artifacts"))
    .writingJSONLines(to: URL(fileURLWithPath: ".premise/runs.jsonl"))

try await forAll(Strategy<Int>.integers(in: 0...100), config: config) { value in
    #expect(value <= 100)
}
```

Useful presets:

| Preset | Intended use |
| --- | --- |
| `.quick` | Fast local feedback |
| `.default` | Normal development checks |
| `.thorough` | Larger exploratory runs |
| `.ci` | CI-friendly timeout and diagnostics |

Use explicit examples for edge cases and known failures:

```swift
try await forAll(
    Strategy<Int>.integers(in: 0...100),
    explicitExamples: [0, 100],
    examples: [.xfail(42, reason: "known production bug")]
) { value in
    #expect(value != 42)
}
```

Use data-aware properties when validity depends on the generated value:

```swift
try await forAll(Strategy<Int>.integers(in: -100...100)) { value, data in
    try data.assume(value != 0, reason: "division by zero")
    #expect(100 / value <= 100)
}
```

## Replay and trace tooling

Premise can print copy-paste reproduction blobs in adapter diagnostics:

```swift
let config = PropertyConfig.ci.printingReproductionBlob()
```

Replay a blob directly:

```swift
let trace = try ChoiceTrace.decodeReproductionBlob("premise-trace-v1:...")
let result = await runner.runDetailed(property, replayTraces: [trace])
```

Inspect persisted traces or exported artifacts from the command line:

```bash
swift package premise-replay .premise/artifacts/failure.premise-trace.json
swift package premise-replay --blob 'premise-trace-v1:...'
```

> [!TIP]
> Commit important replay traces into a corpus directory and use
> `.replayingCorpus(from:)` so CI always starts with known regressions.

## Stateful testing

Use rule-based state machines when correctness depends on valid operation
sequences:

```swift
import PremiseStrategies
import PremiseTesting

struct CounterHarness: Sendable {
    var model = 0
    var system = 0
}

struct ModelMismatch: Error {}

var machine = RuleBasedStateMachine(initialState: CounterHarness())

machine.rule("increment", argument: Strategy<Int>.integers(in: 1...3)) { state, amount in
    state.model += amount
    state.system += amount
}

machine.rule(
    "decrement",
    argument: Strategy<Int>.integers(in: 1...3),
    precondition: { $0.system > 0 },
    { state, amount in
        state.model -= min(amount, state.model)
        state.system -= min(amount, state.system)
    }
)

machine.invariant("model matches system") { state in
    guard state.model == state.system else { throw ModelMismatch() }
}

try await checkRuleBasedStateMachine(
    machine,
    config: StateMachineConfig(maxExamples: 50, maxSteps: 20, seed: 42)
)
```

State machines support initialize rules, teardown actions, preconditions,
bundles, consuming bundle values, multiple outputs, invariant init control,
minimal failing programs, and persisted replay traces.

For simpler model-based tests, generate an explicit operation list with
`checkOperationSequence`.

## Ghostwriter and fuzzing

Generate starter properties with the SwiftPM command plugin:

```bash
swift package premise-ghostwriter \
  --kind roundtrip \
  --module MyApp \
  --type Payload \
  --strategy 'Strategy<Payload>.payloads()' \
  --encode 'try JSONEncoder().encode($0)' \
  --decode 'try JSONDecoder().decode(Payload.self, from: $0)'
```

Supported templates:

- `fuzz-no-crash`
- `roundtrip`
- `equivalence`
- `idempotence`
- `binary-operation-laws`

Bridge libFuzzer, AFL, or custom byte-input harnesses through `PremiseFuzzing`:

```swift
import Foundation
import PremiseFuzzing
import PremiseStrategies

try await fuzzOneInput(
    Data(fuzzerBytes),
    strategy: Strategy<Payload>.payloads()
) { payload in
    _ = try PayloadParser.parse(payload)
}
```

Failing fuzz inputs are saved as Premise replay traces, with the original bytes
recorded in run statistics for triage.

## Optional `@given` macro

The default manifest is macro-free: core products build without downloading a
macro artifact or resolving `swift-syntax`. If you want decorator-style syntax,
opt in to the macro product:

```bash
PREMISE_MACRO_SOURCE=1 swift build --product PremiseMacros
```

```swift
import Testing
import PremiseMacros
import PremiseTesting

@given(.integers(in: 0...100), .ascii)
func lengthDoesNotReduceNumber(n: Int, text: String) {
    #expect(n + text.count >= n)
}
```

## Package map

| Product | Purpose |
| --- | --- |
| `PremiseCore` | Choice traces, runners, shrink machines, reports, config |
| `PremiseStrategies` | Built-in strategies, combinators, derivation helpers |
| `PremiseDatabase` | File-backed, SQLite, and composite failure persistence |
| `PremiseTesting` | swift-testing adapter and stateful testing APIs |
| `PremiseXCTest` | XCTest adapter |
| `PremiseFuzzing` | Byte-input fuzzing bridge |
| `PremiseGhostwriter` | Property-test skeleton generation |
| `PremiseParallel` | Parallel property execution |
| `PremiseTelemetry` | Engine event hooks and telemetry sinks |
| `PremiseCoverageGuided` | SanitizerCoverage snapshots and coverage guidance |
| `PremiseMacros` | Optional `@given` macro |

## Local development

```bash
# Build all default products
swift build

# Run tests
swift test

# Validate target boundaries
bash scripts/validate-boundaries.sh

# Build optional source macros
PREMISE_MACRO_SOURCE=1 swift build --product PremiseMacros
```

> [!IMPORTANT]
> Use a Swift toolchain with the `Testing` module available for the Swift
> Testing test targets. The package itself is SwiftPM-first and builds without
> optional macro dependencies by default.

## Learn more

- [How the engine works](Sources/PremiseCore/Documentation.docc/Articles/HowTheEngineWorks.md)
- [Failure persistence and replay](Sources/PremiseCore/Documentation.docc/Articles/FailurePersistenceAndReplay.md)
- [Stateful rule machines](Sources/PremiseCore/Documentation.docc/Articles/StatefulRuleMachines.md)
- [Ghostwriter and fuzzer bridge](Sources/PremiseCore/Documentation.docc/Articles/GhostwriterAndFuzzing.md)
