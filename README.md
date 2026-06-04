# Swift Premise

A Swift-native property-based testing framework built around a deterministic
choice-trace engine. Premise produces minimal, replayable counterexamples
with structural shrinking — and it does so under Swift 6 strict concurrency
from day one.

## Features

- **Deterministic replay** — every failure is captured as a choice trace that
  reproduces the exact same counterexample.
- **Structural shrinking** — the engine automatically minimizes failing inputs
  so you see the simplest case that breaks your property.
- **Persistent failure storage** — failing traces are written to disk and
  replayed first on subsequent runs, so regressions stay caught.
- **Protocol-witness strategies** — generators use a value-oriented
  `Strategy<Value>` design with no existential overhead in the hot path.
- **Swift 6 strict concurrency** — all public APIs are `Sendable`-safe with
  complete concurrency checking.
- **Adapters for swift-testing and XCTest** — thin integration layers let you
  use Premise with either test framework.

## Installation

Add Premise as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/Premise.git", from: "1.0.0"),
]
```

The first stable release is tagged `v1.0.0`; SwiftPM version requirements omit
the `v` prefix and use `from: "1.0.0"`.

Then add the targets you need:

```swift
.testTarget(
    name: "MyTests",
    dependencies: [
        // For swift-testing:
        .product(name: "PremiseTesting", package: "SwiftPremise"),
        // Or for XCTest:
        .product(name: "PremiseXCTest", package: "SwiftPremise"),
    ]
)
```

### Requirements

- Swift 6.2+
- macOS 13+ / iOS 16+ / tvOS 16+ / watchOS 9+ / visionOS 1+

## Quick Start

### swift-testing

```swift
import Testing
import PremiseTesting
import PremiseStrategies

@Test func additionIsCommutative() async throws {
    try await forAll(.integers(in: -1000...1000)) { x in
        try await forAll(.integers(in: -1000...1000)) { y in
            #expect(x + y == y + x)
        }
    }
}
```

### XCTest

```swift
import XCTest
import PremiseXCTest
import PremiseStrategies

final class MathTests: XCTestCase {
    func testAdditionIsCommutative() async throws {
        try await premise_forAll(.integers(in: -1000...1000)) { x in
            try await premise_forAll(.integers(in: -1000...1000)) { y in
                XCTAssertEqual(x + y, y + x)
            }
        }
    }
}
```

## Strategies

Premise ships a catalog of built-in strategies in `PremiseStrategies`:

| Strategy | Description |
|----------|-------------|
| `.integers(in: 0...100)` | Integers in a closed range (edge-biased) |
| `.booleans` | Random `Bool` values |
| `.floats(in: 0.0...1.0)` | Doubles in a closed range (edge-biased) |
| `.bytes(length: 16)` | Fixed-length byte arrays |
| `.strings(from: chars, length: 1...10)` | Strings from a character set |
| `.ascii`, `.letter`, `.digit`, `.unicode` | Character strategies |
| `Strategy<String>.unicode(length: 5...20)` | Unicode strings |
| `Strategy<Date>.any`, `.dates(in: range)` | Date generation |
| `Strategy<UUID>.any` | Random v4 UUIDs |
| `Strategy<URL>.http` | Random HTTP/HTTPS URLs |
| `.just(value)`, `.constant(value)` | Constant values |
| `.elements(of: [...])` | Uniform choice from array |
| `.permutations(of: [...])` | Fisher-Yates shuffle |
| `strategy.map { ... }` | Transform output |
| `strategy.flatMap { ... }` | Dependent generation |
| `strategy.filter { ... }` | Post-condition filter |
| `strategy.assume { ... }` | Precondition filter |
| `strategy.suchThat { ... }` | Assumption-style precondition filter |
| `Strategy.sized(maxSize:) { ... }` | Size-aware generation |
| `strategy.optional()` | Wraps in `Optional` |
| `strategyA \|\|\| strategyB` | Choice operator (`oneOf`) |
| `zip(s1, s2, s3)` | Variadic tuple composition |
| `.edgeCaseFloats(...)` | Finite/NaN/Inf/denormal/epsilon float cases |
| `.arrays(of:count:)` | Exact-size collection generation |
| `.arrays(of:minCount:maxCount:)` | Min/max collection generation |
| `.denseVector(...)`, `.sparseVector(...)` | Vector-ish numeric data |
| `.quantizedValues(...)` | Quantized numeric buckets |
| `.indexOperations(...)` | Generic index workflow operations |

### Custom Strategies

Build your own `Strategy<Value>` with a draw function and an optional shrinker:

```swift
let positiveEven = Strategy<Int>(
    label: "positiveEven",
    draw: { data in
        let n = data.drawInteger(in: UInt64(1)...UInt64(500))
        return Int(n) * 2
    },
    shrink: { value in
        guard value > 2 else { return [] }
        return [value - 2]
    }
)
```

Replace or add custom shrink behavior with `shrinking`:

```swift
let smallFirst = positiveEven.shrinking { value in
    value > 2 ? [2, value / 2] : []
}
```

## Configuration

Use built-in presets or chainable builders:

```swift
// Presets
try await forAll(.integers(in: 0...100), config: .quick) { n in ... }    // 20 runs
try await forAll(.integers(in: 0...100), config: .thorough) { n in ... } // 1,000 runs
try await forAll(.integers(in: 0...100), config: .ci) { n in ... }       // 500 runs, 60s timeout

// Chainable builders
let config = PropertyConfig.default
    .runs(200)
    .seed(42)
    .timeout(seconds: 30)
    .replayingCorpus(from: URL(fileURLWithPath: ".premise/corpus"))
    .exportingFailureTraces(to: URL(fileURLWithPath: ".premise/artifacts"))

// Full memberwise init
let config = PropertyConfig(
    maxRuns: 200,
    maxShrinkIterations: 500,
    seed: 42
)
```

Use a committed replay corpus when CI finds a failure that should become a
permanent regression case. JSON failure trace artifacts can be uploaded by CI,
reviewed, and copied into the corpus so future runs replay them before fresh
generation.

## Stateful Testing

`PremiseTesting` includes a small operation-sequence checker for model-based
database and index workflows:

```swift
try await checkOperationSequence(
    operations,
    initialModel: ModelState(),
    initialSystem: DatabaseState()
) { model, system in
    #expect(model.snapshot == system.snapshot)
}
```

Generate shrinkable operation lists with:

```swift
let operations = Strategy<[IndexOperation]>.indexOperationSequences(
    length: 1...50,
    indexRange: 0...10,
    value: -100...100
)
```

## Optional @given Macro

For zero-boilerplate property tests, use the `@given` macro (inspired by Hypothesis's `@given` decorator):

```swift
import PremiseMacros
import PremiseTesting

@given(.integers(in: 0...100), .ascii)
func additionIsCommutative(a: Int, s: String) {
    #expect(a + s.count >= a)
}

// With configuration:
@given(.integers(in: 0...100), config: .thorough)
func largeSearchSpace(n: Int) {
    #expect(n * 2 / 2 == n)
}
```

The default manifest is macro-free: `PremiseCore`, `PremiseStrategies`, and
`PremiseTesting` build without downloading a macro artifact or resolving
`swift-syntax`.

To work on `@given` locally, opt into source macros:

```bash
PREMISE_MACRO_SOURCE=1 swift build --product PremiseMacros
```

Release automation validates the binary macro path with:

```bash
PREMISE_MACRO_BINARY=1 \
PREMISE_MACRO_BINARY_CHECKSUM=<checksum> \
swift package dump-package
```

## Package Structure

| Module | Purpose |
|--------|---------|
| `PremiseCore` | Deterministic choice-trace engine, runner, shrink machine |
| `PremiseStrategies` | Built-in generation strategies and combinators |
| `PremiseDatabase` | File-backed (v1) and SQLite WAL (v2) failure persistence |
| `PremiseTesting` | swift-testing adapter (`forAll`) |
| `PremiseXCTest` | XCTest adapter (`premise_forAll`) |
| `PremiseParallel` | Parallel property execution (v2) |
| `PremiseTelemetry` | Engine event hooks and telemetry sinks (v2) |
| `PremiseMacros` | Optional `@given` macro (source or release-binary opt-in) |

The default build ships the five v1 products. V2 extension modules are additive
and don't change the v1 API surface. Optional trait-gated targets exist for
coverage-guided exploration (`CoverageGuided` trait) and SMT-backed providers
(`SMT` trait).

## How It Works

1. **Draw** — the engine feeds random choices through a `PrimitiveProvider` and
   records every decision in a `ChoiceTrace`.
2. **Test** — your property closure receives the generated value and either
   passes or throws.
3. **Shrink** — on failure, the `ShrinkMachine` replays progressively simpler
   traces until it finds a minimal counterexample.
4. **Persist** — the failing trace and its `FailureRecord` are saved to the
   example database.
5. **Replay** — on the next run, persisted failures are replayed first so
   regressions fail immediately.

## Validation

```bash
swift build
swift test
```

With full boundary enforcement:

```bash
bash scripts/validate-boundaries.sh
swift build --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors
swift test --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors
swift build -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md), [RULES.md](RULES.md), and
[WORKFLOW.md](WORKFLOW.md) before opening a PR.

## Security

See [SECURITY.md](SECURITY.md) for vulnerability reporting instructions.

## License

MIT — see [LICENSE](LICENSE).
