# How the Engine Works

A guided tour of the choice-trace model that drives generation, shrinking, and replay.

## The Central Insight

Most property-based testing frameworks generate values directly — they have a random number generator that knows how to produce integers, strings, lists, and so on. When a test fails, shrinking has to work at the value level, trying smaller integers or shorter strings one at a time.

Premise works differently. It generates values *indirectly* through a **choice trace**: a recorded sequence of primitive random draws. Every integer, boolean, and byte that a strategy reads is recorded as an entry in the trace. Shrinking then works at the *trace level* — it tries removing or reducing entries in the trace and re-runs the strategy to see what value comes out.

This separation is the key to Premise's shrinking power. The engine doesn't need to know the structure of your value to shrink it; it only needs to find a shorter or simpler trace that the strategy still accepts and that still fails your property.

## PremiseData: The Draw Interface

``PremiseData`` is the object passed to every strategy's `draw` closure. It is the strategy's window into the random source.

```swift
public struct PremiseData: Sendable {
    public mutating func drawInteger(in range: ClosedRange<Int>) -> Int
    public mutating func drawInteger(in range: ClosedRange<UInt64>) -> UInt64
    public mutating func drawBoolean() -> Bool
    public mutating func drawBytes(count: Int) -> [UInt8]
    public mutating func withSpan<T>(_ label: String?, _ body: (inout Self) throws -> T) rethrows -> T
}
```

Every call to one of the `draw` methods does two things:

1. **Reads** a raw value from the underlying ``PrimitiveProvider``
2. **Records** that value as an entry in the current ``ChoiceTrace``

The trace accumulates the complete sequence of decisions made to produce one generated value.

### Spans

`withSpan` is used by collection strategies to group the draw calls for one element together. Spans give the ``ShrinkMachine`` the structural information it needs to delete entire elements from a collection during shrinking.

```swift
// From CollectionStrategies.swift — each element gets its own span
for _ in 0..<count {
    let value = try data.withSpan { spanData in
        try element.draw(&spanData)
    }
    values.append(value)
}
```

## PrimitiveProvider: The Random Source

``PrimitiveProvider`` is the protocol that backs ``PremiseData``. It has two concrete implementations:

### PseudoRandomProvider

Used during fresh generation. It takes a seed and uses a fast XOR-shift hash to produce pseudo-random bits. Each run index gets its own seed derived as `baseSeed + UInt64(runIndex)`, ensuring deterministic per-run behaviour.

```swift
public struct PseudoRandomProvider: PrimitiveProvider {
    public init(seed: UInt64, maxDraws: Int = .max)
}
```

### ReplayProvider

Used during replay. Instead of generating new random bits, it reads back the recorded values from a saved ``ChoiceTrace`` in order. This is what makes failure reproduction exact: the same trace always produces the same value from the same strategy.

```swift
public struct ReplayProvider: PrimitiveProvider {
    public init(trace: ChoiceTrace)
}
```

## ChoiceTrace: The Record

``ChoiceTrace`` is a sequence of ``ChoiceTrace/Entry`` values plus a list of ``ChoiceTrace/Span`` annotations:

```swift
public struct ChoiceTrace: Sendable, Codable, Equatable {
    public enum Entry: Sendable, Codable, Equatable {
        case bits(BitEntry)
        case integer(UInt64)
        case boolean(Bool)
        case bytes([UInt8])
    }
    public struct Span: Sendable, Codable, Equatable {
        public var label: String?
        public var start: Int  // index into entries
        public var end: Int
    }
    public var entries: [Entry]
    public var spans: [Span]
}
```

The entries are the raw choices. The spans describe the boundaries of logical sub-values (like individual elements of an array).

## Runner: Orchestrating Runs

``Runner`` is the top-level driver. It generates fresh test cases, replays stored traces, and invokes the ``ShrinkMachine`` when a failure is found.

```swift
public struct Runner<Value: Sendable>: Sendable {
    public let strategy: Strategy<Value>
    public let config: PropertyConfig
    public let propertyID: PropertyIdentity

    public func runDetailed(
        explicitExamples: [Value] = [],
        _ property: @escaping @Sendable (Value, inout PremiseData) throws -> Void,
        replayTraces: [ChoiceTrace] = []
    ) async -> DetailedRunResult<Value>

    public func runDetailed(
        explicitExamples: [Value] = [],
        _ property: @escaping @Sendable (Value) throws -> Void,
        replayTraces: [ChoiceTrace] = []
    ) async -> DetailedRunResult<Value>

    public func run(
        _ property: @escaping @Sendable (Value) throws -> Void,
        replayTraces: [ChoiceTrace] = []
    ) async -> RunResult<Value>
}
```

`run` returns the compact ``RunResult`` used by low-level callers. Use
`runDetailed` when an adapter or custom harness needs execution diagnostics;
it returns a ``DetailedRunResult``:

```swift
public enum DetailedRunResult<Value: Sendable>: Sendable {
    case passed(RunReport)
    case failure(FailureRecord, value: Value, report: RunReport)
}
```

### Phases and explicit examples

Detailed runs execute the phases listed in `PropertyConfig.phases`. The default
order is `.explicit`, `.replay`, `.generate`, `.shrink`:

```swift
let config = PropertyConfig.default
    .phases([.explicit, .generate, .shrink])

let runner = Runner(
    strategy: Strategy<Int>.integers(in: 0...100),
    config: config
)

let result = await runner.runDetailed(
    explicitExamples: [0, 1, 2]
) { value, data in
    data.event(value.isMultiple(of: 2) ? "even" : "odd")
    data.note("value", value: value)
    data.target(Double(value), label: "magnitude")
}
```

Explicit examples are caller-provided values. They run before replay and fresh
generation in the default phase order, and failures from them are reported with
`runCount == 0`. The `.replay` phase consumes persisted ``ChoiceTrace`` values
when replay is enabled. The `.generate` phase draws fresh examples from the
strategy. The `.shrink` phase controls whether a discovered failure is minimized
before being returned; if omitted, the first failing value is reported without
trace minimization.

### Run reports

``RunReport`` aggregates observations across all attempted examples in a
detailed run:

```swift
public struct RunReport: Sendable, Codable, Equatable {
    public var runCount: Int
    public var rejectedCount: Int
    public var phaseCounts: [PropertyPhase: Int]
    public var events: [String: Int]
    public var notes: [RunNote]
    public var maxTargetScore: Double?
    public var healthWarnings: [HealthWarning]
}
```

`phaseCounts` records how many successful or failing attempts ran in each
phase. `events` counts labels recorded with ``PremiseData/event(_:)``. `notes`
contains observations recorded with ``PremiseData/note(_:value:)`` after
aggregation. ``PremiseData/target(_:label:)`` updates `maxTargetScore`; labeled
target observations are folded into that maximum rather than retained as report
notes. `healthWarnings` contains non-fatal execution quality warnings from
enabled checks, such as empty search spaces or excessive filtering.

The compact run loop:

1. **Replay phase** — if `config.replayEnabled` is true, each stored trace is fed to a ``ReplayProvider`` and replayed against the property. If any replayed trace still fails, that failure is returned immediately (no fresh generation needed).

2. **Generation phase** — the runner iterates `config.maxRuns` times. Each iteration creates a ``PseudoRandomProvider`` from a derived seed, runs the strategy to draw a value, and passes the value to the property closure.

3. **Shrink phase** — when a fresh failure is found, the runner invokes ``ShrinkMachine/run()`` with the failing trace, collects the minimised trace, and re-runs the strategy with a ``ReplayProvider`` to obtain the minimised value.

4. **Result** — the runner returns either `.passed(runs:)` or `.failure(_:value:)` containing the ``FailureRecord`` and the minimised counterexample value.

## ShrinkMachine: Minimising Failures

``ShrinkMachine`` receives the first failing trace and iteratively tries simpler alternatives, keeping any that still fail the property. It runs three types of passes in a loop until no pass makes progress:

### Deletion pass

Tries to delete the entries covered by each span. If removing an element's entries still produces a failing trace, the element is eliminated.

### Integer pass

For each integer entry in the trace, tries `0`, `value/2`, and `value-1`. Smaller integers generally produce smaller generated values.

### Collection pass

For spans that are preceded by a length entry, tries reducing the length by one and removing the last element.

The machine stops when no pass makes progress or the shrink budget is exhausted.

## Strategy: The Generation Witness

``Strategy<Value>`` is a value type that captures two closures:

```swift
public struct Strategy<Value: Sendable>: Sendable {
    public let label: String
    public let draw: @Sendable (inout PremiseData) throws -> Value
    public let shrink: @Sendable (Value) -> [Value]
}
```

The `draw` closure reads from ``PremiseData`` to produce a `Value`. The `shrink` closure is an optional value-level shrinker that supplements the trace-level shrinking in the engine. Built-in strategies like `integers(in:)` provide both.

## The Lifecycle of One Property Test

Putting it all together, here is what happens when `forAll(.integers(in: 0...100)) { n in ... }` is called:

```
forAll(strategy, config)
  │
  ▼
ReplayFirstExecutor
  │  1. Load stored traces from FileBackedDatabase
  │  2. runner.runDetailed(property, replayTraces: storedTraces)
  │
  ▼
Runner.runDetailed
  │  Explicit phase:
  │    run caller-provided examples first, if any
  │
  │  Replay phase:
  │    for each stored trace:
  │      ReplayProvider(trace) → PremiseData → strategy.draw → value → property(value)
  │      if throws: return .failure (skip generation)
  │
  │  Generation phase:
  │    for index in 0..<maxRuns:
  │      PseudoRandomProvider(seed + index) → PremiseData → strategy.draw → value
  │      property(value)
  │      if throws:
  │        ShrinkMachine(failingTrace).run() → minimalTrace
  │        ReplayProvider(minimalTrace) → minimalValue
  │        return .failure(FailureRecord, minimalValue, RunReport)
  │
  │  return .passed(RunReport)
  │
  ▼
ReplayFirstExecutor
  │  3. If failure: database.save(record)
  │  4. Return result
  │
  ▼
forAll
  │  If failure: Issue.record(...) / XCTFail(...)
```

## Next Steps

- Read <doc:ShrinkingExplained> for a deeper dive into shrinking strategies.
- Read <doc:FailurePersistenceAndReplay> to understand how traces are stored and loaded.
- Read <doc:CustomStrategies> to learn how to write your own `Strategy<Value>`.
