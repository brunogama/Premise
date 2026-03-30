# Shrinking Explained

How Premise automatically minimises failing inputs to the simplest possible counterexample.

## The Problem Without Shrinking

Imagine a property test that exercises a parser. You ask the engine to generate strings up to 200 characters long. The engine finds a failure on input 157 — a messy, partially-valid 89-character string:

```
"user:alice\nrole:admin\nexpiry:2024-01-01\nbad_line\nmore_data=true\n..."
```

That input is hard to read, hard to debug, and may contain many irrelevant parts. The actual bug might only require three characters to trigger. Without shrinking, you're left with the full mess.

## What Shrinking Does

Shrinking is the process of finding the *minimum* input that still causes the property to fail. The ``ShrinkMachine`` takes the first failing trace and iteratively produces candidate smaller traces, keeping each one that the property still rejects, until no further reduction is possible.

The result is something like:

```
"bad_line"
```

or even just:

```
"x"
```

This minimal counterexample is far easier to understand, and often makes the root cause of the bug immediately obvious.

## Two Levels of Shrinking

Premise operates on two levels simultaneously.

### Trace-level shrinking (the primary mechanism)

The ``ShrinkMachine`` works on the ``ChoiceTrace`` — the sequence of raw choices that produced the value — rather than on the value itself. This is the key architectural insight.

Because every generated value is deterministically reproduced from its trace, the machine can:

1. Try a *shorter* trace (delete entries)
2. Try a trace with *smaller integers* at certain positions
3. Re-run the strategy with each candidate trace to see what value comes out
4. Keep the candidate if the resulting value still fails the property

This means the machine doesn't need to know the structure of your `Value` type. If your strategy generates a `User` struct by drawing an integer for the age and a string for the name, the machine can shrink the age by reducing the integer entry in the trace — automatically, with no extra code from you.

### Value-level shrinking (the supplement)

The `shrink` closure in ``Strategy`` provides value-level candidates. For primitive strategies, this is straightforward:

```swift
// From StandardStrategies.swift
shrink: { value in
    guard value != range.lowerBound else { return [] }
    let midpoint = range.lowerBound + ((value - range.lowerBound) / 2)
    let candidates = Set([range.lowerBound, 0, midpoint])
    return candidates
        .filter { range.contains($0) && $0 < value }
        .sorted()
}
```

The engine tries each candidate from `shrink` before falling back to trace-level deletion. For custom strategies where trace-level shrinking is insufficient, providing a good `shrink` closure significantly improves the quality of the counterexample.

## How ShrinkMachine Works

``ShrinkMachine`` is a deterministic loop that runs three passes until no pass makes progress.

### Pass 1: Deletion

The machine scans the span list in reverse order. For each span, it tries removing all the trace entries it covers. If the resulting shorter trace still reproduces the failure, the shorter trace becomes the new best.

This is how collection elements get removed: each element has its own span, so the machine can delete elements one at a time, keeping the ones that aren't needed.

```
Before: [count=3] [spanA: 0, 1] [spanB: 2, 3] [spanC: 4, 5]
Try:    [count=3] [spanA: 0, 1] [spanB: 2, 3]   ← delete spanC
Try:    [count=3] [spanA: 0, 1]                   ← delete spanB  
Try:    [count=3]                                  ← delete spanA
```

### Pass 2: Integer reduction

The machine scans each integer entry in the trace. For each one it tries the candidates `0`, `value/2`, and `value - 1`. If a smaller integer still reproduces the failure, the trace is updated.

This is how numeric values get minimised, and also how collection lengths get reduced — since `count` entries are integers too.

```
Before: [count=7] [...]
Try:    [count=0] [...]  → still fails? keep it
Try:    [count=3] [...]  → ...
Try:    [count=6] [...]  → ...
```

### Pass 3: Collection reduction

For spans that are immediately preceded by an integer entry (a length), the machine tries decrementing the length by 1 and removing the corresponding span. This handles the case where deletion alone can't reduce a collection because the length entry and the element entries need to change together.

## Shrink Quality Tips

### Provide a value-level shrinker for custom strategies

If your strategy generates a complex value, provide a `shrink` closure that returns simpler candidates:

```swift
let personStrategy = Strategy<Person>(
    label: "person",
    draw: { data in
        let age  = data.drawInteger(in: 0...120)
        let name = try nameStrategy.draw(&data)
        return Person(name: name, age: age)
    },
    shrink: { person in
        // Try age 0, then the midpoint, then age-1
        var candidates: [Person] = []
        if person.age > 0 { candidates.append(Person(name: person.name, age: 0)) }
        if person.age > 1 { candidates.append(Person(name: person.name, age: person.age / 2)) }
        return candidates
    }
)
```

### Use spans for logical groupings

When drawing the components of a compound value, use `withSpan` to group them. This lets the deletion pass remove the whole component at once:

```swift
let pairStrategy = Strategy<(Int, Int)>(
    label: "pair",
    draw: { data in
        try data.withSpan("pair") { d in
            let a = d.drawInteger(in: 0...100)
            let b = d.drawInteger(in: 0...100)
            return (a, b)
        }
    },
    shrink: { _ in [] }
)
```

### Keep draw closures simple

Strategies with complex conditional logic (heavy use of `filter`, deeply nested `flatMap`) can confuse the trace-level shrinker, because small changes to trace entries may produce values that don't satisfy the filters and are discarded. Prefer direct draws with post-processing over filtering.

## The Shrink Budget

``PropertyConfig/maxShrinkIterations`` limits how many shrink attempts the machine makes per failure. The default is 500. Increase it for complex strategies that take many iterations to reach a minimal counterexample:

```swift
let config = PropertyConfig(maxShrinkIterations: 2000)
try await forAll(complexStrategy, config: config) { value in ... }
```

## Next Steps

- Read <doc:FailurePersistenceAndReplay> to see how the minimised trace is saved and replayed.
- Read <doc:CustomStrategies> for guidance on writing `shrink` closures for your own types.
