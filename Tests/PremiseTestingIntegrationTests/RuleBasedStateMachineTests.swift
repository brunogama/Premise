import Foundation
import Testing

@testable import PremiseCore
@testable import PremiseDatabase
@testable import PremiseTesting
@testable import PremiseStrategies


@Test("Rule machine executes generated operations and invariants")
func ruleMachineExecutesRulesAndInvariants() async throws {
  var machine = RuleBasedStateMachine(initialState: CounterMachine())

  addCounterRules(to: &machine)
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

  addIsolationRules(to: &machine, first: first, second: second)
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

  addEmptyBundleRules(to: &machine, ids: ids)
  try await checkRuleBasedStateMachine(
    machine,
    config: StateMachineConfig(maxExamples: 1, maxSteps: 2, seed: 1)
  )

  #expect(await recorder.snapshot() == ["created", "consumed-1"])
}


@Test("Initialize rules run before invariants and normal rules")
func initializeRulesRunBeforeInvariantsAndNormalRules() async throws {
  var machine = RuleBasedStateMachine(
    initialState: PhaseMachine(initialized: false, recorder: nil)
  )

  addInitializationRule(to: &machine)

  machine.invariant("initialized", checkDuringInit: false) { state in
    guard state.initialized else {
      throw StateMachineTestError.invariantFailure
    }
  }

  machine.rule("advance", argument: Strategy<Int>.just(1)) { state, value in
    guard state.initialized else {
      throw StateMachineTestError.ruleFailure
    }
    state.phase += value
  }

  try await checkRuleBasedStateMachine(
    machine,
    config: StateMachineConfig(maxExamples: 2, maxSteps: 2, seed: 11)
  )
}

private func addInitializationRule(
  to machine: inout RuleBasedStateMachine<PhaseMachine>
) {
  machine.initialize("seed", argument: Strategy<Int>.just(1)) { state, _ in
    state.initialized = true
  }
}

@Test("Teardown runs after normal rule execution")
func teardownRunsAfterNormalRuleExecution() async throws {
  let recorder = RuleRecorder()
  var machine = RuleBasedStateMachine(
    initialState: PhaseMachine(initialized: true, recorder: recorder)
  )

  machine.rule("work", argument: Strategy<Int>.just(1)) { state, value in
    state.phase += value
  }

  machine.teardown("finish") { state in
    guard state.phase > 0 else {
      throw StateMachineTestError.teardownFailure
    }
    let recorder = state.recorder
    await recorder?.record("teardown-\(state.phase)")
  }

  try await checkRuleBasedStateMachine(
    machine,
    config: StateMachineConfig(maxExamples: 1, maxSteps: 2, seed: 12)
  )

  #expect(await recorder.snapshot() == ["teardown-2"])
}

@Test("Consuming bundles remove selected values")
func consumingBundlesRemoveSelectedValues() async throws {
  let ids = StateMachineBundle<Int>("ids")
  var machine = RuleBasedStateMachine(
    initialState: PhaseMachine(initialized: true, recorder: nil)
  )

  addConsumingBundleRules(to: &machine, ids: ids)
  try await checkRuleBasedStateMachine(
    machine,
    config: StateMachineConfig(maxExamples: 1, maxSteps: 3, seed: 13)
  )
}


@Test("Rules can emit multiple bundle outputs")
func rulesCanEmitMultipleBundleOutputs() async throws {
  let ids = StateMachineBundle<Int>("ids")
  let labels = StateMachineBundle<String>("labels")
  var machine = RuleBasedStateMachine(
    initialState: PhaseMachine(initialized: true, recorder: nil)
  )

  addMultipleOutputRules(to: &machine, ids: ids, labels: labels)
  try await checkRuleBasedStateMachine(
    machine,
    config: StateMachineConfig(maxExamples: 1, maxSteps: 3, seed: 14)
  )
}
