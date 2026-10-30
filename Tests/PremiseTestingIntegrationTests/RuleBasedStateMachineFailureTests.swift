import Foundation
import Testing

@testable import PremiseCore
@testable import PremiseDatabase
@testable import PremiseTesting
@testable import PremiseStrategies

@Test("State machine failures include minimized programs and replay traces")
func stateMachineFailuresIncludeMinimizedProgramsAndReplayTraces() async throws {
  var machine = RuleBasedStateMachine(initialState: CounterMachine())

  machine.rule("set bad", argument: Strategy<Int>.integers(in: 1...5)) { state, value in
    state.model = value
    state.system = value + 1
  }

  machine.invariant("model matches system") { state in
    guard state.model == state.system else {
      throw StateMachineTestError.invariantFailure
    }
  }

  do {
    try await checkRuleBasedStateMachine(
      machine,
      config: StateMachineConfig(maxExamples: 1, maxSteps: 3, seed: 15, maxShrinkIterations: 10)
    )
    #expect(Bool(false))
  } catch let failure as StateMachineFailure {
    #expect(!failure.replayTrace.entries.isEmpty)
    #expect(!failure.program.steps.isEmpty)
    #expect(failure.description.contains("program="))
    #expect(failure.description.contains("set bad"))
  }
}

@Test("State machine failures persist and replay traces")
func stateMachineFailuresPersistAndReplayTraces() async throws {
  let propertyID = PropertyIdentity(
    fileID: "RuleBasedStateMachineTests.swift",
    line: 500,
    strategyLabel: "state-machine-persistence",
    functionName: "stateMachineFailuresPersistAndReplayTraces"
  )
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  var machine = RuleBasedStateMachine(initialState: CounterMachine())

  machine.rule("fail", argument: Strategy<Int>.just(1)) { _, _ in
    throw StateMachineTestError.ruleFailure
  }

  do {
    try await checkRuleBasedStateMachine(
      machine,
      config: persistenceConfig(maxExamples: 1, propertyID: propertyID, directory: directory)
    )
    #expect(Bool(false))
  } catch is StateMachineFailure {
    // The failure is persisted for the replay assertion below.
  }

  let database = FileBackedDatabase(rootDirectory: directory)
  let traces = try await database.loadTraces(for: propertyID)
  #expect(!traces.isEmpty)

  do {
    try await checkRuleBasedStateMachine(
      machine,
      config: persistenceConfig(maxExamples: 0, propertyID: propertyID, directory: directory)
    )
    #expect(Bool(false))
  } catch let failure as StateMachineFailure {
    #expect(failure.exampleIndex < 0)
    #expect(failure.ruleName == "fail")
  }
}

private func persistenceConfig(
  maxExamples: Int,
  propertyID: PropertyIdentity,
  directory: URL
) -> StateMachineConfig {
  StateMachineConfig(
    maxExamples: maxExamples,
    maxSteps: 1,
    seed: 16,
    propertyID: propertyID,
    localDatabaseDirectory: directory
  )
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
