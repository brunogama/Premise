# Strategy Catalog

A reference for every built-in strategy in PremiseStrategies.

## Overview

Strategies are values of type ``Strategy``\<Value\> that describe how to generate and shrink a particular type. All built-in strategies live in the `PremiseStrategies` module and are added as extensions on `Strategy<Value>` conditioned on the concrete `Value` type.

Import the module to use them:

```swift
import PremiseStrategies
```

## Primitive Strategies

### Integers

```swift
static func integers(in range: ClosedRange<Int>) -> Strategy<Int>
static func integers(in range: ClosedRange<UInt64>) -> Strategy<UInt64>
```

Generates an integer within the given closed range. The distribution is *edge-biased*: values `range.lowerBound`, `range.upperBound`, and `0` (when in range) are selected with elevated probability. This bias means the engine tries boundary values early in each run sequence, which is where bugs most commonly hide.

```swift
.integers(in: 0...255)       // UInt8-range integers
.integers(in: -1000...1000)  // signed integers with edge bias
.integers(in: 1...Int.max)   // large range, still edge-biased
```

**Shrinking:** Towards `range.lowerBound`. Candidates include `lowerBound`, `0`, and the midpoint between `lowerBound` and the current value.

### Booleans

```swift
static var booleans: Strategy<Bool>
```

Generates `true` or `false` with equal probability.

**Shrinking:** `true` shrinks to `[false]`; `false` shrinks to `[]`.

### Floats (Doubles)

```swift
static func floats(in range: ClosedRange<Double>) -> Strategy<Double>
```

Generates a `Double` within the given range. Also edge-biased: tries `lowerBound`, `upperBound`, `0` (when in range), and the midpoint before falling back to uniform sampling.

```swift
.floats(in: 0.0...1.0)      // unit interval
.floats(in: -1.0...1.0)     // signed unit interval
```

**Shrinking:** Towards `lowerBound`. Candidates are `lowerBound`, `0`, and the midpoint between `lowerBound` and the current value.

### Raw Bytes

```swift
static func bytes(length: Int) -> Strategy<[UInt8]>
static func bytes(length: ClosedRange<Int>) -> Strategy<[UInt8]>
```

Generates a `[UInt8]` of a fixed or variable length. Useful for testing parsers, hashing functions, and any system that processes opaque binary data.

```swift
.bytes(length: 16)          // always 16 bytes
.bytes(length: 1...512)     // variable length, edge-biased count
```

**Shrinking:** Drops the last byte. Empty arrays don't shrink.

### Strings

```swift
static func strings(from characters: [Character], length: ClosedRange<Int>) -> Strategy<String>
```

Generates a `String` whose characters are drawn from the provided character set, with a variable length in the given range.

```swift
let lowercase = Array("abcdefghijklmnopqrstuvwxyz")
let digits    = Array("0123456789")

.strings(from: lowercase, length: 1...20)
.strings(from: lowercase + digits, length: 0...50)
```

**Shrinking:** Drops the last character.

## Collection Strategies

These strategies live in the same module and produce Swift collection types.

### Arrays

```swift
static func arrays(of element: Strategy<Element>, length: ClosedRange<Int>) -> Strategy<[Element]>
```

Generates an array of the given element strategy, with a variable length. The count is edge-biased (tries 0, max, and random lengths). Each element draw is wrapped in a span so the shrink machine can delete individual elements.

```swift
.arrays(of: .integers(in: 0...100), length: 0...20)
.arrays(of: .booleans, length: 1...10)
```

**Shrinking:** Drops the last element, or tries the empty array.

### Dictionaries

```swift
static func dictionaries<Key: Hashable & Sendable, Element: Sendable>(
    keys: Strategy<Key>,
    values: Strategy<Element>,
    count: ClosedRange<Int>
) -> Strategy<[Key: Element]>
```

Generates a `[Key: Element]` dictionary. Duplicate keys are resolved by taking the later value. Pairs are drawn in a stable sort order to make shrinking deterministic.

```swift
.dictionaries(
    keys: .strings(from: lowercase, length: 1...10),
    values: .integers(in: 0...1000),
    count: 0...5
)
```

**Shrinking:** Drops the last key-value pair.

### Sets

```swift
static func sets<Element: Hashable & Sendable>(
    of element: Strategy<Element>,
    count: ClosedRange<Int>
) -> Strategy<Set<Element>>
```

Generates a `Set<Element>`. Elements are drawn in stable sort order.

```swift
.sets(of: .integers(in: 0...50), count: 0...10)
```

**Shrinking:** Drops the last element.

## Combinators

Combinators transform or compose existing strategies.

### map

```swift
func map<NewValue: Sendable>(_ transform: @escaping @Sendable (Value) -> NewValue) -> Strategy<NewValue>
```

Transforms each generated value:

```swift
let evenIntegers = Strategy<Int>.integers(in: 0...50)
    .map { $0 * 2 }
```

### flatMap

```swift
func flatMap<NewValue: Sendable>(
    _ transform: @escaping @Sendable (Value) -> Strategy<NewValue>
) ) -> Strategy<NewValue>
```

Generates a strategy from a generated value — useful when the shape of one value depends on another:

```swift
let countThenArray = Strategy<Int>.integers(in: 1...10)
    .flatMap { count in
        .arrays(of: .integers(in: 0...100), length: count...count)
    }
```

### filter

```swift
func filter(
    _ predicate: @escaping @Sendable (Value) -> Bool,
    maxAttempts: Int = 32
) -> Strategy<Value>
```

Keeps only values that satisfy the predicate. Use sparingly — if the predicate rejects too many values, the engine will exhaust its draw budget.

```swift
let positiveOdd = Strategy<Int>.integers(in: 0...100)
    .filter { $0 % 2 != 0 }
```

### optional

```swift
func optional() -> Strategy<Value?>
```

Wraps any strategy in `Optional`, producing `nil` roughly half the time.

```swift
let maybeString = Strategy<String>.strings(from: lowercase, length: 1...10)
    .optional()
```

**Shrinking:** A non-nil value shrinks to `nil` first, then to smaller non-nil values.

### oneOf

```swift
static func oneOf(_ strategies: [Strategy<Value>]) -> Strategy<Value>
```

Picks one of the given strategies uniformly at random and draws from it:

```swift
let special = Strategy<String>.oneOf([
    .just(""),
    .just("null"),
    .strings(from: lowercase, length: 1...20),
])
```

### frequency

```swift
static func frequency(_ weightedStrategies: [(Int, Strategy<Value>)]) -> Strategy<Value>
```

Like `oneOf` but with relative weights:

```swift
let mostly3Digits = Strategy<Int>.frequency([
    (5, .integers(in: 100...999)),  // 5x likely
    (1, .integers(in: 0...9)),      // 1x likely
    (1, .integers(in: 1000...9999)),
])
```

### just

```swift
static func just(_ value: Value) -> Strategy<Value>
```

Always returns the same constant value. Useful as a base case in recursive strategies or to mix a known constant into a `oneOf`.

```swift
.just(0)
.just("")
.just(Date.distantPast)
```

### constant

```swift
static func constant(_ value: Value) -> Strategy<Value>
```

Alias for `just`. Reads better when the intent is a fixed sentinel:

```swift
.constant(0)
.constant("")
```

### elements(of:)

```swift
static func elements(of values: [Value]) -> Strategy<Value>
```

Chooses uniformly from a non-empty array of fixed values. Shrinks toward the first element.

```swift
let status = Strategy<Int>.elements(of: [200, 201, 204, 301, 400, 404, 500])
let suit = Strategy<String>.elements(of: ["hearts", "diamonds", "clubs", "spades"])
```

### permutations(of:)

```swift
static func permutations(of values: [Value]) -> Strategy<[Value]>
```

Generates a random permutation of the given array using a Fisher-Yates shuffle driven by the choice sequence. Shrinks to the identity (original order).

```swift
let shuffled = Strategy<Int>.permutations(of: [1, 2, 3, 4, 5])
```

### assume

```swift
func assume(
    _ predicate: @escaping @Sendable (Value) -> Bool,
    maxAttempts: Int = 32
) -> Strategy<Value>
```

Precondition filter. Like `filter`, but communicates intent more clearly: "I assume this holds for the values I'm testing." Throws `StrategyError.assumptionFailed` when exhausted.

```swift
let nonEmpty = Strategy<String>.ascii.assume { !$0.isEmpty }
```

### zip (variadic)

```swift
func zip<each T: Sendable>(
    _ strategy: repeat Strategy<each T>
) -> Strategy<(repeat each T)>
```

Combines an arbitrary number of strategies into a tuple using Swift parameter packs. Each component is drawn independently; shrinking delegates to trace-based `ShrinkMachine`.

```swift
let pair = zip(.integers(in: 0...10), Strategy<String>.ascii)
let triple = zip(.integers(in: 0...10), Strategy<Bool>.booleans, Strategy<String>.ascii)
```

### ||| (choice operator)

```swift
infix operator |||: StrategyChoicePrecedence
```

Syntactic sugar for `oneOf`. Combines two strategies with left-to-right associativity:

```swift
let alphanumeric: Strategy<Character> = .digit ||| .letter
let any = .digit ||| .letter ||| .ascii
```

### recursive

```swift
static func recursive(
    _ config: RecursiveStrategyConfig,
    leaf: Strategy<Value>,
    _ build: @escaping @Sendable (Strategy<Value>) -> Strategy<Value>
) -> Strategy<Value>
```

Generates self-referential values like trees, JSON, or nested structures. The `config` controls the maximum depth and desired branching. See <doc:AdvancedCombinators> for a full worked example.

## Foundation Strategies

These strategies generate common Foundation types. Import `PremiseStrategies` to use them.

### Characters

```swift
static var ascii: Strategy<Character>    // printable ASCII (U+0020…U+007E)
static var letter: Strategy<Character>   // a-z, A-Z
static var digit: Strategy<Character>    // 0-9
static var unicode: Strategy<Character>  // BMP, excluding surrogates
```

```swift
.ascii    // any printable ASCII character
.letter   // letters only
.digit    // digits only
.unicode  // any BMP character
```

**Shrinking:** All shrink to `"a"` (letters/ascii/unicode) or `"0"` (digit).

### Unicode Strings

```swift
static var unicode: Strategy<String>                           // 0...100 BMP characters
static func unicode(length: ClosedRange<Int>) -> Strategy<String>  // custom length range
```

```swift
Strategy<String>.unicode                // variable-length Unicode string
Strategy<String>.unicode(length: 5...20)  // controlled length
```

**Shrinking:** Drops the last character.

### Dates

```swift
static var any: Strategy<Date>                                    // epoch to 2099-12-31
static func dates(in range: ClosedRange<Date>) -> Strategy<Date>  // custom range
```

```swift
Strategy<Date>.any
Strategy<Date>.dates(in: startOfYear...endOfYear)
```

**Shrinking:** Towards Unix epoch (1970-01-01), or `range.lowerBound` if epoch is out of range.

### UUIDs

```swift
static var any: Strategy<UUID>
```

Generates random v4 UUIDs with correct version (4) and variant (RFC 4122) bits.

```swift
Strategy<UUID>.any
```

**Shrinking:** None (UUIDs have no natural ordering).

### URLs

```swift
static var http: Strategy<URL>
```

Generates HTTP/HTTPS URLs with random hosts, TLDs, and path segments.

```swift
Strategy<URL>.http
// e.g. https://xkqmwf.io/abc/def
```

**Shrinking:** Towards `https://a.com`.

## Result Builders

### @StrategyBuilder

Compose strategies declaratively with `if`/`else` support:

```swift
let shape: Strategy<Shape> = buildStrategy {
    Strategy.just(.circle(radius: 1))
    Strategy.just(.square(side: 1))
    if includeTriangles {
        Strategy.just(.triangle(base: 1, height: 1))
    }
}
```

### @WeightedStrategyBuilder

Frequency-based composition:

```swift
let biasedCoin: Strategy<Bool> = buildWeightedStrategy {
    WeightedStrategy(weight: 3, .just(true))
    WeightedStrategy(weight: 1, .just(false))
}
```

## Type-Driven Derivation

Use `StrategyRegistry` when generic helpers need a strategy by type instead of
receiving a strategy value directly. Registries are immutable, so each
registration returns a scoped copy that is safe to pass into one property or
fixture without mutating global state.

```swift
let registry = StrategyRegistry.standard
  .register(UserID.self) { registry in
    registry.strategy(for: Int.self)
      .map { UserID(rawValue: $0) }
  }
let userIDs = registry.strategy(for: UserID.self)
```

The closure form keeps strict-concurrency checking explicit and lets derived
strategies depend on other registered strategies. Domain types can also conform
to `StrategyProviding` when they should derive themselves from whichever
registry a test supplies.

## Next Steps

- See <doc:AdvancedCombinators> for detailed examples of `flatMap`, `frequency`, and `recursive`.
- See <doc:CustomStrategies> to build a `Strategy<Value>` for your own domain types.
- See <doc:StatefulRuleMachines> for rule-based stateful testing examples.
- See <doc:GivenMacroAndConfiguration> for the `@given` macro and `PropertyConfig` presets.
