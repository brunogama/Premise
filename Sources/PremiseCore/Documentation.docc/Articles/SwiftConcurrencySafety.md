# Swift Concurrency Safety

How Premise is designed for Swift 6 strict concurrency from the ground up.

## The Baseline

Premise targets Swift 6 language mode with complete concurrency checking enabled. All public APIs are `Sendable`, all shared mutable state is actor-isolated, and `PremiseCore` has zero imports from `Testing` or `XCTest`. This is not a compatibility layer — it is the designed baseline.

```swift
// Package.swift
swiftLanguageModes: [.v6]
```

If you use Premise from a Swift 6 target, you get full concurrency checking at compile time at no extra cost.

## Sendable Throughout

Every type you interact with is `Sendable`:

```swift
public struct Strategy<Value: Sendable>: Sendable { ... }
public struct Runner<Value: Sendable>: Sendable { ... }
public struct PropertyConfig: Sendable { ... }
public struct ChoiceTrace: Sendable, Codable, Equatable { ... }
public struct FailureRecord: Sendable, Codable, Equatable { ... }
public enum RunResult<Value: Sendable>: Sendable { ... }
```

The `Value: Sendable` constraint on `Strategy` and `Runner` means the generated values are safe to pass across concurrency boundaries — both to the property closure and to the `ShrinkMachine`.

### Closures are @Sendable

The `draw` and `shrink` closures in ``Strategy`` are both `@Sendable`:

```swift
public struct Strategy<Value: Sendable>: Sendable {
    public let draw:   @Sendable (inout PremiseData) throws -> Value
    public let shrink: @Sendable (Value) -> [Value]
}
```

And the property closure you pass to `forAll` is also `@Sendable`:

```swift
public func forAll<Value: Sendable>(
    _ strategy: Strategy<Value>,
    _ property: @escaping @Sendable (Value) throws -> Void
) async throws { ... }
```

This means the compiler will catch any attempt to capture non-`Sendable` state in your property closures at compile time. For example, capturing a reference-type model object in a property closure requires that object to be `Sendable` or actor-isolated.

## Actors for Shared Mutable State

### ExampleDatabase is an Actor protocol

``ExampleDatabase`` is declared as an `Actor` protocol:

```swift
public protocol ExampleDatabase: Actor {
    func loadTraces(for id: PropertyIdentity) async throws -> [ChoiceTrace]
    func save(_ record: FailureRecord) async throws
    func clear(for id: PropertyIdentity) async throws
}
```

All database operations are asynchronous and actor-isolated, preventing data races between the engine's write of a new failure and any concurrent reads.

### FileBackedDatabase is an actor

```swift
public actor FileBackedDatabase: ExampleDatabase { ... }
```

### TelemetryRelay is an actor

```swift
public actor TelemetryRelay {
    public func register(_ sink: any TelemetrySink) { ... }
    public func emit(_ event: EngineEvent) async { ... }
}
```

### ParallelRunner's result collector is an actor

The result collector inside ``ParallelRunner`` that merges failure results from concurrent tasks is also an actor:

```swift
private actor ResultCollector<Value: Sendable> {
    func recordFailure(at index: Int, failure: IndexedFailure<Value>) { ... }
    func earliestFailure() -> IndexedFailure<Value>? { ... }
}
```

## PremiseCore Has No Framework Imports

``PremiseCore`` deliberately imports nothing from `Testing` or `XCTest`. This is enforced by a build-time boundary check script (`scripts/validate-boundaries.sh`).

The reasons:

1. **Portability**: `PremiseCore` can be used in command-line tools, server-side Swift, and Swift Package Manager plugins without pulling in test framework dependencies.
2. **Testability**: The engine's own unit tests can exercise `PremiseCore` directly through `swift test` without a test framework adapter.
3. **Strict concurrency reasoning**: A smaller import surface reduces the risk of accidentally importing types with weaker concurrency guarantees.

The adapters `PremiseTesting` (imports `Testing`) and `PremiseXCTest` (imports `XCTest`) are thin wrappers. They construct a ``Runner``, wrap it in a ``ReplayFirstExecutor``, call `execute`, and translate the ``RunResult`` into the appropriate test framework failure API.

## PrimitiveProviderState: Copy-on-Write Inside PremiseData

``PremiseData`` holds a `PrimitiveProviderState` — a copy-on-write wrapper around a generic provider. This design lets `PremiseData` be a value type (a `struct`) while still supporting arbitrary concrete provider types at runtime, without existential boxing in the hot draw path.

```swift
// PremiseData is a struct — it can be passed by value
public struct PremiseData: Sendable {
    private var provider: PrimitiveProviderState  // CoW wrapper
    private var spanStarts: [SpanStart]
    public private(set) var trace: ChoiceTrace
    public private(set) var status: Status
}
```

The `@unchecked Sendable` on `PrimitiveProviderBoxBase` and `PrimitiveProviderBox` is a deliberate, contained use of the escape hatch. These classes are private implementation details not accessible through any public API. They hold a `Provider` value that is itself `Sendable`, and are accessed only through a single `PrimitiveProviderState` owned by one `PremiseData` at a time.

## Writing @Sendable Property Closures

Because the property closure is `@escaping @Sendable`, you may not capture non-`Sendable` values. Common patterns:

### Capturing immutable value types — fine

```swift
let multiplier = 3  // Int is Sendable
try await forAll(.integers(in: 1...100)) { n in
    #expect(n * multiplier == multiplier * n)
}
```

### Capturing an actor — fine

```swift
@MainActor class ViewModel { ... }
let vm = ViewModel()

// Access the actor through await inside the closure
try await forAll(.strings(from: lowercase, length: 1...20)) { input in
    let result = await vm.process(input)
    #expect(!result.isEmpty)
}
```

### Capturing a class — requires Sendable or @unchecked Sendable

```swift
// If MyService is not Sendable, this won't compile under Swift 6:
// let service = MyService()
// try await forAll(...) { value in service.process(value) }  ← error

// Solutions:
// 1. Make MyService Sendable (preferred)
// 2. Wrap it in an actor
// 3. Use @unchecked Sendable with explicit synchronisation (last resort)
```

## Next Steps

- Read <doc:ParallelTesting> to see how concurrent runs are safely coordinated.
- Read <doc:TelemetryAndObservability> for the actor-based telemetry design.
