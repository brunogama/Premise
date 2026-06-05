# Stateful Rule Machines

Use rule-based state machines to test workflows whose correctness depends on a sequence of operations.

## Overview

Most property tests draw one value, run one assertion, and shrink the failing
input. Stateful systems need a wider lens: caches, indexes, queues, parsers,
and clients often fail only after several valid operations interact.

A rule-based state machine describes that workflow as a set of named rules. For
each generated example, Premise creates a fresh state value, checks all
invariants, repeatedly chooses an enabled rule, draws the rule argument, runs
the rule body, and checks the invariants again.

Use a rule machine when the engine should choose the next operation at runtime.
Use an operation-sequence strategy when you already want to generate a plain
array of operations and interpret it yourself.

## Value State

For pure value state, `initialState` is the most convenient initializer. The
same starting value is used for every generated example, which works naturally
for structs and enums.

```swift
import PremiseCore
import PremiseStrategies
import PremiseTesting

struct CounterHarness: Sendable {
    var model = 0
    var system = 0
}

enum InvariantViolation: Error {
    case modelMismatch
}

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
    guard state.model == state.system else {
        throw InvariantViolation.modelMismatch
    }
}

try await checkRuleBasedStateMachine(
    machine,
    config: StateMachineConfig(maxExamples: 50, maxSteps: 20, seed: 42)
)
```

Rules receive the mutable state and a generated argument. A precondition decides
whether the rule is currently enabled. Invariants run before the first step and
after every executed rule.

## Reference-Backed State

Use `makeInitialState` for reference-backed state such as actors, databases,
file-system sandboxes, indexes, or clients. The factory runs once per generated
example, so one example cannot leak storage into the next.

```swift
import PremiseCore
import PremiseStrategies
import PremiseTesting

actor IndexHarness {
    private var model: Set<Int> = []
    private var index: Set<Int> = []

    func insert(_ value: Int) {
        model.insert(value)
        index.insert(value)
    }

    func delete(_ value: Int) {
        model.remove(value)
        index.remove(value)
    }

    func matchesModel() -> Bool {
        index == model
    }
}

enum InvariantViolation: Error {
    case modelMismatch
}

var machine = RuleBasedStateMachine(makeInitialState: { IndexHarness() })

machine.rule("insert", argument: Strategy<Int>.integers(in: 0...100)) { state, value in
    await state.insert(value)
}

machine.rule("delete", argument: Strategy<Int>.integers(in: 0...100)) { state, value in
    await state.delete(value)
}

machine.invariant("index matches model") { state in
    guard await state.matchesModel() else {
        throw InvariantViolation.modelMismatch
    }
}

try await checkRuleBasedStateMachine(machine)
```

`initialState` is still useful for pure value state. Prefer `makeInitialState`
whenever the state holds reference identity, external resources, or mutable
storage that must be rebuilt between examples.

## Preconditions

Preconditions keep the generated workflow valid without forcing every rule body
to handle impossible operations. For example, a dequeue rule can be enabled only
when the queue is non-empty.

```swift
machine.rule(
    "dequeue",
    argument: Strategy<Void>.just(()),
    precondition: { state in
        await state.canDequeue()
    },
    { state, _ in
        await state.dequeue()
    }
)
```

If no rules are enabled, the current example stops early. This lets the model
express terminal states without failing the test.

## Bundles

Bundles pass values produced by one rule to later rules. They are scoped to one
generated example, so saved values never leak across examples or across bundles
with the same label.

```swift
let ids = StateMachineBundle<Int>("ids")
var machine = RuleBasedStateMachine(makeInitialState: { IndexHarness() })

machine.rule(
    "create id",
    argument: Strategy<Int>.integers(in: 1...10),
    target: ids,
    { state, id in
        await state.insert(id)
        return id
    }
)

machine.rule("delete existing id", argument: ids.strategy()) { state, id in
    await state.delete(id)
}
```

When a bundle is empty, a consuming rule is skipped for that draw. This is
useful for workflows like "create, then update" or "open, then close" where
later operations need values discovered during the run.

## Failure Metadata

When a rule, precondition, state factory, or invariant throws,
`checkRuleBasedStateMachine` reports a `StateMachineFailure`. The failure
includes the base seed, generated example index, step index, phase, and the
rule or invariant name when available. Use those fields to reproduce and narrow
stateful failures without guessing which operation caused the break.
