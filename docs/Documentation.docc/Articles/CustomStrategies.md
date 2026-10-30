# Custom Strategies

Build a Strategy<Value> for any domain type using PremiseData primitives.

## The Strategy Contract

A ``Strategy``\<Value\> captures two pieces of behaviour in a single value:

1. **`draw`** — given a mutable ``PremiseData``, produce a `Value`
2. **`shrink`** — given a `Value`, return simpler candidates to try

```swift
public struct Strategy<Value: Sendable>: Sendable {
    public let label: String
    public let draw: @Sendable (inout PremiseData) throws -> Value
    public let shrink: @Sendable (Value) -> [Value]

    public init(
        label: String,
        draw: @escaping @Sendable (inout PremiseData) throws -> Value,
        shrink: @escaping @Sendable (Value) -> [Value] = { _ in [] }
    )
}
```

The `draw` closure is called once per generated run. The `shrink` closure is called by the ``ShrinkMachine`` during failure minimisation, in addition to the trace-level shrinking the engine performs automatically.

## Step 1: Draw from PremiseData

Use ``PremiseData``'s draw methods to read random values. Every call is recorded in the trace, which makes the draw deterministically replayable.

```swift
let temperatureStrategy = Strategy<Double>(
    label: "temperature",
    draw: { data in
        // Use the built-in float draw — edge-biased toward extremes
        data.drawInteger(in: 0...4) == 0
            ? -273.15  // absolute zero as a special case
            : Double(data.drawInteger(in: 0...UInt64(50000))) / 100.0 - 273.15
    }
)
```

For most types, it's simpler to compose from the existing built-in strategies using `map` or `flatMap`:

```swift
let temperatureStrategy = Strategy<Double>.floats(in: -273.15...200.0)
```

## Step 2: Compose Fields

For structs with multiple fields, draw each field in sequence:

```swift
struct Point { var x: Double; var y: Double }

let pointStrategy = Strategy<Point>(
    label: "point",
    draw: { data in
        let x = Double(data.drawInteger(in: -1000...1000))
        let y = Double(data.drawInteger(in: -1000...1000))
        return Point(x: x, y: y)
    },
    shrink: { point in
        var candidates: [Point] = []
        if point.x != 0 { candidates.append(Point(x: 0, y: point.y)) }
        if point.y != 0 { candidates.append(Point(x: point.x, y: 0)) }
        candidates.append(Point(x: 0, y: 0))
        return candidates
    }
)
```

## Step 3: Use withSpan for Compound Values

Wrap compound draws in ``PremiseData/withSpan(_:_:)`` so the ``ShrinkMachine`` can treat the whole group as a unit during the deletion pass:

```swift
struct Edge { var from: Int; var to: Int }

let edgeStrategy = Strategy<Edge>(
    label: "edge",
    draw: { data in
        try data.withSpan("edge") { d in
            let from = d.drawInteger(in: 0...99)
            let to   = d.drawInteger(in: 0...99)
            return Edge(from: from, to: to)
        }
    },
    shrink: { edge in
        guard edge.from != 0 || edge.to != 0 else { return [] }
        return [Edge(from: 0, to: 0)]
    }
)
```

## Step 4: Add a Shrink Closure

The shrink closure returns simpler candidates. Simpler typically means:

- Smaller numbers (`0`, `lowerBound`, `value / 2`)
- Shorter strings or collections
- Structurally simpler variants (e.g. the "nil" case of an optional, the base case of a recursive type)

Return candidates in *increasing order of simplicity* — the machine tries them in order and keeps the first one that still fails.

```swift
struct User {
    var name: String
    var age: Int
    var isAdmin: Bool
}

let userStrategy = Strategy<User>(
    label: "user",
    draw: { data in
        let nameLen = data.drawInteger(in: 1...20)
        let name    = String((0..<nameLen).map { _ in
            let idx = data.drawInteger(in: 0...25)
            return Character(UnicodeScalar(UInt8(97 + idx)))  // a-z
        })
        let age     = data.drawInteger(in: 0...120)
        let isAdmin = data.drawBoolean()
        return User(name: name, age: age, isAdmin: isAdmin)
    },
    shrink: { user in
        var candidates: [User] = []
        // Try non-admin first (removes the most dangerous flag)
        if user.isAdmin {
            candidates.append(User(name: user.name, age: user.age, isAdmin: false))
        }
        // Try age 0
        if user.age > 0 {
            candidates.append(User(name: user.name, age: 0, isAdmin: user.isAdmin))
        }
        // Try single-character name
        if user.name.count > 1 {
            candidates.append(User(name: "a", age: user.age, isAdmin: user.isAdmin))
        }
        // Try the minimal user
        candidates.append(User(name: "a", age: 0, isAdmin: false))
        return candidates
    }
)
```

## Using Extension Syntax

Extend `Strategy` conditioned on `Value` for a clean, discoverable API that matches the built-in style:

```swift
extension Strategy where Value == User {
    static var users: Strategy<User> {
        // implementation above
    }

    static func admins(ageRange: ClosedRange<Int> = 18...65) -> Strategy<User> {
        Strategy<User>(
            label: "admins(age: \(ageRange))",
            draw: { data in
                let age = data.drawInteger(in: ageRange)
                return User(name: "admin", age: age, isAdmin: true)
            },
            shrink: { user in
                guard user.age > ageRange.lowerBound else { return [] }
                return [User(name: "admin", age: ageRange.lowerBound, isAdmin: true)]
            }
        )
    }
}

// Usage
try await forAll(.users) { user in ... }
try await forAll(.admins()) { admin in ... }
try await forAll(.admins(ageRange: 18...25)) { admin in ... }
```

## Throwing Draw Closures

If the draw closure throws, the run is marked as exhausted (not as a property failure). Use throws for invalid combinations you can't avoid:

```swift
struct Config {
    var retries: Int
    var timeout: TimeInterval
}

let validConfig = Strategy<Config>(
    label: "validConfig",
    draw: { data in
        let retries = data.drawInteger(in: 0...10)
        let rawTimeout = data.drawInteger(in: 1...3600)
        let timeout = TimeInterval(rawTimeout)
        guard timeout > TimeInterval(retries) else {
            // Timeout must be greater than number of retries
            // Throwing here marks this draw as invalid, not a failure
            throw DrawError.invalidCombination
        }
        return Config(retries: retries, timeout: timeout)
    }
)

enum DrawError: Error { case invalidCombination }
```

Prefer constructing valid values directly over throwing — filtering via throws reduces the effective run count.

## Combining with Built-in Strategies

The cleanest custom strategies delegate to existing ones where possible:

```swift
struct EmailAddress: Sendable {
    let localPart: String
    let domain: String
    var address: String { "\(localPart)@\(domain)" }
}

extension Strategy where Value == EmailAddress {
    static var emails: Strategy<EmailAddress> {
        let safe = Array("abcdefghijklmnopqrstuvwxyz0123456789._-")
        let local  = Strategy<String>.strings(from: safe, length: 1...20)
        let domain = Strategy<String>.strings(from: safe, length: 3...15)
            .map { $0 + ".com" }

        return local.flatMap { lp in
            domain.map { d in EmailAddress(localPart: lp, domain: d) }
        }
    }
}
```

## Debugging with sample()

Before wiring your strategy into a property test, inspect what it generates using `sample(count:seed:)` and `sampleOne(seed:)`:

```swift
let emails = Strategy<EmailAddress>.emails

// Draw 5 values and print them
let examples = emails.sample(count: 5)
for email in examples {
    print(email.address)
}

// Draw a single value with a fixed seed (reproducible)
let one = emails.sampleOne(seed: 42)
print(one.address)
```

`sample` is purely for debugging — it creates a temporary `PremiseData` under the hood and does not participate in shrinking or replay. Use it during development to verify your strategy produces reasonable values before running full property tests.

## Testing Your Strategy

Write a property that verifies the strategy itself:

```swift
@Test func emailStrategyAlwaysProducesValidAddress() async throws {
    try await forAll(.emails) { email in
        #expect(email.address.contains("@"))
        #expect(email.address.split(separator: "@").count == 2)
        #expect(!email.localPart.isEmpty)
        #expect(!email.domain.isEmpty)
    }
}
```

## Next Steps

- See <doc:AdvancedCombinators> for `flatMap`, `oneOf`, `frequency`, `zip`, `|||`, and result builders.
- See <doc:GivenMacroAndConfiguration> for the `@given` macro and `PropertyConfig` presets.
- See the tutorial <doc:WritingCustomStrategy> for a step-by-step walkthrough building a full domain strategy.
