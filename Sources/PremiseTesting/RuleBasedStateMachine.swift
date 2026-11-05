import PremiseCore
import PremiseDatabase

/// Runs the given machine for several generated examples.
public func checkRuleBasedStateMachine<State: Sendable>(
  _ machine: RuleBasedStateMachine<State>,
  config: StateMachineConfig = StateMachineConfig()
) async throws {
  let database = config.localDatabaseDirectory.map {
    FileBackedDatabase(rootDirectory: $0)
  }
  let runner = StateMachineCheckRunner(
    machine: machine,
    config: config,
    database: database,
    baseSeed: config.seed ?? UInt64.random(in: .min ... .max)
  )
  try await runner.run()
}

// swiftlint:disable:next function_parameter_count - Machine, configuration, provider, and run metadata have separate owners.
func runOnce<State: Sendable, Provider: PrimitiveProvider>(
  _ machine: RuleBasedStateMachine<State>,
  config: StateMachineConfig,
  provider: Provider,
  metadata: StateMachineRunMetadata
) async throws {
  let state: State
  do {
    state = try await machine.makeInitialState()
  } catch {
    throw stateMachineFailure(
      wrapping: error,
      metadata: metadata,
      step: -1,
      phase: .stateFactory
    )
  }
  var execution = StateMachineExecution(
    machine: machine,
    config: config,
    metadata: metadata,
    state: state,
    data: PremiseData(provider: provider)
  )
  try await execution.run()
}

// swiftlint:disable:next function_parameter_count - Rules and state are evaluated at a specific run and step.
func enabledRules<State: Sendable>(
  _ rules: [StateMachineRule<State>],
  state: State,
  metadata: StateMachineRunMetadata,
  step: Int
) async throws -> [StateMachineRule<State>] {
  var enabled: [StateMachineRule<State>] = []
  enabled.reserveCapacity(rules.count)
  for rule in rules {
    do {
      if try await rule.isEnabled(state) {
        enabled.append(rule)
      }
    } catch {
      throw stateMachineFailure(
        wrapping: error,
        metadata: metadata,
        step: step,
        phase: .precondition,
        ruleName: rule.name
      )
    }
  }
  return enabled
}

// swiftlint:disable:next function_parameter_count - Invariants, state, run, step, and initialization phase are independent inputs.
func checkInvariants<State: Sendable>(
  _ invariants: [StateMachineInvariant<State>],
  state: State,
  metadata: StateMachineRunMetadata,
  step: Int,
  duringInit: Bool
) async throws {
  for invariant in invariants where !duringInit || invariant.checkDuringInit {
    do {
      try await invariant.check(state)
    } catch {
      throw stateMachineFailure(
        wrapping: error,
        metadata: metadata,
        step: step,
        phase: .invariant,
        invariantName: invariant.name
      )
    }
  }
}

func executeTeardowns<State: Sendable>(
  _ teardowns: [StateMachineTeardown<State>],
  state: inout State,
  metadata: StateMachineRunMetadata
) async throws {
  for teardown in teardowns {
    do {
      try await teardown.body(&state)
    } catch {
      throw stateMachineFailure(
        wrapping: error,
        metadata: metadata,
        step: -1,
        phase: .teardown,
        ruleName: teardown.name
      )
    }
  }
}


// swiftlint:disable:next function_parameter_count - Error, run, step, phase, rule, and invariant identify distinct failure details.
func stateMachineFailure(
  wrapping error: any Error,
  metadata: StateMachineRunMetadata,
  step: Int,
  phase: StateMachineFailure.Phase,
  ruleName: String? = nil,
  invariantName: String? = nil
) -> StateMachineFailure {
  if let failure = error as? StateMachineFailure {
    return failure
  }

  return StateMachineFailure(
    baseSeed: metadata.baseSeed,
    exampleIndex: metadata.exampleIndex,
    step: step,
    phase: phase,
    underlyingDescription: String(describing: error),
    ruleName: ruleName,
    invariantName: invariantName
  )
}
