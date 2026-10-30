# Advanced Combinators

Build complex strategies from simple ones using flatMap, filter, oneOf, frequency, and recursive.

## Overview

Simple strategies for primitives are easy. Real domain types — users, requests, trees, JSON — require combining and transforming strategies. The combinators in `PremiseStrategies` give you a composable toolkit for generating any value your code can accept.

## flatMap: Dependent Generation

`flatMap` lets the output of one strategy determine which strategy generates the next value. This is essential when values have dependencies between their fields.

### Example: arrays of exactly N elements

Suppose you need an array whose length matches a separately-drawn integer:

```swift
let pairedLengthAndArray = Strategy<Int>.integers(in: 1...10)
    .flatMap { count in
        Strategy<[Int]>.arrays(
            of: .integers(in: 0...100),
            length: count...count
        ).map { array in (count, array) }
    }

// Generated values always satisfy: value.0 == value.1.count
try await forAll(pairedLengthAndArray) { count, array in
    #expect(array.count == count)
}
```

### Example: valid date ranges

Draw a start date first, then draw an end date that is guaranteed to come after it:

```swift
let dateRange = Strategy<Int>.integers(in: 0...3650)
    .flatMap { startOffset in
        Strategy<Int>.integers(in: 0...365).map { duration in
            let start = Date(timeIntervalSinceNow: TimeInterval(startOffset * 86400))
            let end   = start.addingTimeInterval(TimeInterval(duration * 86400))
            return DateInterval(start: start, end: end)
        }
    }
```

## filter: Postcondition Enforcement

`filter` keeps only values satisfying a predicate. Use it for light constraints; avoid it for tight constraints where most values are rejected.

```swift
// Fine: roughly half the values pass
let positiveOdd = Strategy<Int>.integers(in: 1...200)
    .filter { $0 % 2 != 0 }

// Bad: only 1 in 1000 values pass — engine exhausts its draw budget
let primes1To1000 = Strategy<Int>.integers(in: 1...1000)
    .filter { isPrime($0) }  // don't do this
```

For tight constraints, generate the structure directly instead:

```swift
// Better: generate odd numbers directly
let positiveOdd = Strategy<Int>.integers(in: 0...99)
    .map { $0 * 2 + 1 }  // always odd, no filtering
```

## oneOf: Uniform Choice

`oneOf` picks one strategy from a list with equal probability and draws from it. Use it to mix concrete special values with generated ones:

```swift
let httpStatus = Strategy<Int>.oneOf([
    .just(200),
    .just(404),
    .just(500),
    .integers(in: 100...599),  // catch-all
])
```

`oneOf` is also good for `enum` generation:

```swift
enum Color { case red, green, blue, custom(UInt8, UInt8, UInt8) }

let colorStrategy = Strategy<Color>.oneOf([
    .just(.red),
    .just(.green),
    .just(.blue),
    Strategy<Color>(
        label: "custom",
        draw: { data in
            .custom(
                UInt8(data.drawInteger(in: 0...255)),
                UInt8(data.drawInteger(in: 0...255)),
                UInt8(data.drawInteger(in: 0...255))
            )
        },
        shrink: { _ in [.red] }
    ),
])
```

## frequency: Weighted Choice

`frequency` is like `oneOf` but lets you assign relative weights. Higher-weight strategies are chosen more often.

```swift
let mostly_empty_arrays = Strategy<[Int]>.frequency([
    (4, .just([])),                                       // empty 40% of the time
    (3, .arrays(of: .integers(in: 0...10), length: 1...5)), // small 30%
    (2, .arrays(of: .integers(in: 0...10), length: 5...20)),// medium 20%
    (1, .arrays(of: .integers(in: 0...10), length: 20...100)), // large 10%
])
```

This is useful when you know that edge cases (like empty collections) are more likely to expose bugs and should be exercised more frequently.

## recursive: Self-Referential Structures

`recursive` generates tree-shaped and recursively nested values. It requires a leaf strategy (the base case) and a function that takes a strategy for a smaller version of the value and returns a strategy for a larger version.

### Example: expression tree

```swift
indirect enum Expr {
    case num(Int)
    case add(Expr, Expr)
    case mul(Expr, Expr)
}

let exprStrategy = Strategy<Expr>.recursive(
    RecursiveStrategyConfig(
        depth: 4,              // maximum nesting depth
        desiredSize: 3,        // leaf weight
        expectedBranchSize: 2  // branch weight
    ),
    leaf: Strategy<Int>.integers(in: 0...10).map { .num($0) }
) { smaller in
    Strategy<Expr>.oneOf([
        smaller.flatMap { lhs in smaller.map { rhs in .add(lhs, rhs) } },
        smaller.flatMap { lhs in smaller.map { rhs in .mul(lhs, rhs) } },
    ])
}
```

`RecursiveStrategyConfig` controls the balance:

- `depth`: maximum recursion depth (higher = deeper trees, slower generation)
- `desiredSize`: weight of the leaf strategy at each level
- `expectedBranchSize`: weight of the recursive/branch strategy at each level

### Example: JSON-like value

```swift
indirect enum JSON {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSON])
    case object([String: JSON])
}

let letters = Array("abcdefghijklmnopqrstuvwxyz")
let keyStrategy = Strategy<String>.strings(from: letters, length: 1...10)

let jsonStrategy = Strategy<JSON>.recursive(
    RecursiveStrategyConfig(depth: 3, desiredSize: 4, expectedBranchSize: 1),
    leaf: Strategy<JSON>.oneOf([
        .just(.null),
        Strategy<Bool>.booleans.map { .bool($0) },
        Strategy<Double>.floats(in: -1000...1000).map { .number($0) },
        keyStrategy.map { .string($0) },
    ])
) { smaller in
    Strategy<JSON>.oneOf([
        Strategy<[JSON]>.arrays(of: smaller, length: 0...3).map { .array($0) },
        Strategy<[String: JSON]>.dictionaries(
            keys: keyStrategy,
            values: smaller,
            count: 0...3
        ).map { .object($0) },
    ])
}
```

## assume: Precondition on the Generated Domain

`assume` is like `filter` but communicates a clearer intent — "I assume this holds for the values I'm interested in." It's the Swift equivalent of Hypothesis's `assume()`:

```swift
let nonZero = Strategy<Int>.integers(in: -100...100)
    .assume { $0 != 0 }

try await forAll(nonZero) { n in
    #expect(100 / n != 0)  // safe, n is never zero
}
```

If the assumption rejects too many values (default: 32 attempts), the run is silently skipped — not counted as a failure. Use `assume` for light preconditions; for tight constraints, generate the valid domain directly.

## zip: Combining Independent Strategies

`zip` combines any number of strategies into a tuple using Swift parameter packs. This is cleaner than nested `flatMap` when the strategies are independent:

```swift
// Instead of this:
let pair = strategyA.flatMap { a in strategyB.map { b in (a, b) } }

// Write this:
let pair = zip(strategyA, strategyB)
let triple = zip(strategyA, strategyB, strategyC)
```

Shrinking is handled at the trace level by the `ShrinkMachine` — each component's draws are independent spans.

## ||| Operator: Inline Choice

The `|||` operator is syntactic sugar for `oneOf`, useful for quick inline composition:

```swift
let alphanumeric: Strategy<Character> = .digit ||| .letter
let special = .digit ||| .letter ||| .ascii

// Equivalent to:
let alphanumeric = Strategy<Character>.oneOf([.digit, .letter])
```

It associates left-to-right with `StrategyChoicePrecedence` (lower than `ComparisonPrecedence`, higher than `LogicalConjunctionPrecedence`).

## Result Builders: Declarative Composition

### @StrategyBuilder

`buildStrategy` lets you compose strategies with `if`/`else`, `for`, and optional branches:

```swift
let shape: Strategy<Shape> = buildStrategy {
    Strategy.just(.circle(radius: 1))
    Strategy.just(.square(side: 1))
    if includeTriangles {
        Strategy.just(.triangle(base: 1, height: 1))
    }
}
```

Under the hood, this is equivalent to `oneOf` with the strategies listed in the block.

### @WeightedStrategyBuilder

For frequency-based composition, use `buildWeightedStrategy` with explicit weights:

```swift
let logLevel: Strategy<String> = buildWeightedStrategy {
    WeightedStrategy(weight: 5, .just("info"))
    WeightedStrategy(weight: 3, .just("warning"))
    WeightedStrategy(weight: 1, .just("error"))
    WeightedStrategy(weight: 1, .just("critical"))
}
```

This is equivalent to `Strategy.frequency([(5, .just("info")), ...])`, but reads more naturally as a declaration.

## Composing Multiple Combinators

Real domain strategies combine multiple operators:

```swift
struct APIRequest {
    var method: String
    var path: String
    var headers: [String: String]
    var body: Data?
}

let methodStrategy = Strategy<String>.oneOf([
    .just("GET"), .just("POST"), .just("PUT"), .just("DELETE"), .just("PATCH")
])

let pathSegment = Strategy<String>.strings(from: Array("abcdefghijklmnopqrstuvwxyz0123456789-"), length: 1...10)
let pathStrategy = Strategy<[String]>.arrays(of: pathSegment, length: 1...5)
    .map { "/" + $0.joined(separator: "/") }

let headerKey = Strategy<String>.strings(from: Array("abcdefghijklmnopqrstuvwxyz-"), length: 3...15)
    .map { $0.capitalized }
let headerValue = Strategy<String>.strings(from: Array("abcdefghijklmnopqrstuvwxyz0123456789 /-"), length: 1...30)
let headersStrategy = Strategy<[String: String]>.dictionaries(
    keys: headerKey,
    values: headerValue,
    count: 0...5
)

let bodyStrategy = Strategy<Data?>.bytes(length: 0...256)
    .map { Data($0) }
    .optional()

let requestStrategy = methodStrategy.flatMap { method in
    pathStrategy.flatMap { path in
        headersStrategy.flatMap { headers in
            bodyStrategy.map { body in
                APIRequest(method: method, path: path, headers: headers, body: body)
            }
        }
    }
}
```

## Next Steps

- See <doc:CustomStrategies> to build strategies from scratch.
- See <doc:GivenMacroAndConfiguration> for the `@given` macro and `PropertyConfig` presets.
- See the tutorial <doc:UsingCombinators> for a step-by-step walkthrough.
- See the tutorial <doc:RecursiveDataStructures> for a complete recursive strategy example.
