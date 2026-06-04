import Testing

@testable import PremiseCore
@testable import PremiseTesting
@testable import PremiseStrategies

private struct CounterMachine: Sendable {
  var model = 0
  var system = 0
  var saved: [Int] = []
}

private enum StateMachineTestError: Error, CustomStringConvertible, Sendable {
  case bundleLeak
  case invariantFailure
  case referenceStateLeak
  case ruleFailure
  case unexpectedDraw

  var description: String {
    switch self {
    case .bundleLeak: return "bundle leaked values"
    case .invariantFailure: return "invariant failed"
    case .referenceStateLeak: return "reference-backed state leaked"
    case .ruleFailure: return "rule failed"
    case .unexpectedDraw: return "unexpected draw failure"
    }
  }
}

private actor ReferenceStorage {
  private var values: [Int] = []

  func append(_ value: Int) {
    values.append(value)
  }

  func count() -> Int {
    values.count
  }
}

private struct ReferenceBackedMachine: Sendable {
  let storage: ReferenceStorage
}

private actor RuleRecorder {
  private var events: [String] = []

  func record(_ event: String) {
    events.append(event)
  }

  func snapshot() -> [String] {
    events
  }
}

private struct EmptyBundleMachine: Sendable {
  let recorder: RuleRecorder
  var created = false
  var consumed = false
}

private struct BundleIsolationMachine: Sendable {
  var phase = 0
}

@Test("Rule machine executes generated operations and invariants")
func ruleMachineExecutesRulesAndInvariants() async throws {
  var machine = RuleBasedStateMachine(initialState: CounterMachine())

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
    #expect(state.model == state.system)
  }

  try await checkRuleBasedStateMachine(
    machine,
    config: StateMachineConfig(maxExamples: 5, maxSteps: 10, seed: 1)
  )
}

@Test("State factory resets reference-backed state between examples")
func stateFactoryResetsReferenceBackedStateBetweenExamples() async throws {
  var machine = RuleBasedStateMachine(makeInitialState: {
    ReferenceBackedMachine(storage: ReferenceStorage())
  })

  machine.rule("append once", argument: Strategy<Int>.just(1)) { state, value in
    let storage = state.storage
    guard await storage.count() == 0 else {
      throw StateMachineTestError.referenceStateLeak
    }
    await storage.append(value)
  }

  try await checkRuleBasedStateMachine(
    machine,
    config: StateMachineConfig(maxExamples: 3, maxSteps: 1, seed: 1)
  )
}

@Test("Bundles with the same label stay isolated")
func bundlesWithSameLabelStayIsolated() async throws {
  let first = StateMachineBundle<Int>("ids")
  let second = StateMachineBundle<Int>("ids")
  var machine = RuleBasedStateMachine(initialState: BundleIsolationMachine())

  machine.rule(
    "create second",
    argument: Strategy<Int>.just(2),
    precondition: { $0.phase == 0 },
    target: second,
    { state, value in
      state.phase = 1
      return value
    }
  )

  machine.rule(
    "consume missing first",
    argument: first.strategy(),
    precondition: { $0.phase == 1 },
    { _, _ in
      throw StateMachineTestError.bundleLeak
    }
  )

  try await checkRuleBasedStateMachine(
    machine,
    config: StateMachineConfig(maxExamples: 1, maxSteps: 2, seed: 1)
  )
}

@Test("Empty bundle consumers are skipped")
func emptyBundleConsumersAreSkipped() async throws {
  let recorder = RuleRecorder()
  let ids = StateMachineBundle<Int>("ids")
  var machine = RuleBasedStateMachine(
    initialState: EmptyBundleMachine(recorder: recorder)
  )

  machine.rule(
    "consume empty",
    argument: ids.strategy(),
    precondition: { !$0.created },
    { _, _ in
      throw StateMachineTestError.bundleLeak
    }
  )

  machine.rule(
    "create id",
    argument: Strategy<Int>.just(1),
    precondition: { !$0.created },
    target: ids,
    { state, value in
      let recorder = state.recorder
      state.created = true
      await recorder.record("created")
      return value
    }
  )

  machine.rule(
    "consume id",
    argument: ids.strategy(),
    precondition: { $0.created && !$0.consumed },
    { state, value in
      let recorder = state.recorder
      state.consumed = true
      await recorder.record("consumed-\(value)")
    }
  )

  try await checkRuleBasedStateMachine(
    machine,
    config: StateMachineConfig(maxExamples: 1, maxSteps: 2, seed: 1)
  )

  #expect(await recorder.snapshot() == ["created", "consumed-1"])
}

@Test("Rule failures include state machine metadata")
func ruleFailuresIncludeStateMachineMetadata() async throws {
  var machine = RuleBasedStateMachine(initialState: CounterMachine())

  machine.rule("fail rule", argument: Strategy<Int>.just(1)) { _, _ in
    throw StateMachineTestError.ruleFailure
  }

  do {
    try await checkRuleBasedStateMachine(
      machine,
      config: StateMachineConfig(maxExamples: 1, maxSteps: 1, seed: 42)
    )
    #expect(Bool(false))
  } catch let failure as StateMachineFailure {
    #expect(failure.baseSeed == 42)
    #expect(failure.exampleIndex == 0)
    #expect(failure.step == 0)
    #expect(failure.phase == .rule)
    #expect(failure.ruleName == "fail rule")
    #expect(failure.invariantName == nil)
    #expect(failure.underlyingDescription.contains("rule failed"))
  }
}

@Test("Invariant failures include state machine metadata")
func invariantFailuresIncludeStateMachineMetadata() async throws {
  var machine = RuleBasedStateMachine(initialState: CounterMachine())

  machine.invariant("fail invariant") { _ in
    throw StateMachineTestError.invariantFailure
  }

  do {
    try await checkRuleBasedStateMachine(
      machine,
      config: StateMachineConfig(maxExamples: 1, maxSteps: 0)
    )
    #expect(Bool(false))
  } catch let failure as StateMachineFailure {
    #expect(failure.exampleIndex == 0)
    #expect(failure.step == -1)
    #expect(failure.phase == .invariant)
    #expect(failure.ruleName == nil)
    #expect(failure.invariantName == "fail invariant")
    #expect(failure.description.contains("baseSeed="))
    #expect(failure.underlyingDescription.contains("invariant failed"))
  }
}

@Test("Unexpected strategy errors are propagated")
func unexpectedStrategyErrorsArePropagated() async throws {
  let throwing = Strategy<Int>(
    label: "throws",
    draw: { _ in throw StateMachineTestError.unexpectedDraw }
  )
  var machine = RuleBasedStateMachine(initialState: CounterMachine())

  machine.rule("draw fails", argument: throwing) { _, _ in
    #expect(Bool(false))
  }

  do {
    try await checkRuleBasedStateMachine(
      machine,
      config: StateMachineConfig(maxExamples: 1, maxSteps: 1, seed: 7)
    )
    #expect(Bool(false))
  } catch let failure as StateMachineFailure {
    #expect(failure.baseSeed == 7)
    #expect(failure.exampleIndex == 0)
    #expect(failure.step == 0)
    #expect(failure.phase == .rule)
    #expect(failure.ruleName == "draw fails")
    #expect(failure.underlyingDescription.contains("unexpected draw failure"))
  }
}

@Test("Bundles pass values between rules")
func bundlesPassValuesBetweenRules() async throws {
  let ids = StateMachineBundle<Int>("ids")
  var machine = RuleBasedStateMachine(initialState: CounterMachine())

  machine.rule("create id", argument: Strategy<Int>.integers(in: 1...5), target: ids) { state, id in
    state.saved.append(id)
    return id
  }

  machine.rule("consume id", argument: ids.strategy()) { state, id in
    #expect(state.saved.contains(id))
  }

  machine.invariant("saved ids are positive") { state in
    #expect(state.saved.allSatisfy { $0 > 0 })
  }

  try await checkRuleBasedStateMachine(
    machine,
    config: StateMachineConfig(maxExamples: 5, maxSteps: 10, seed: 1)
  )
}
