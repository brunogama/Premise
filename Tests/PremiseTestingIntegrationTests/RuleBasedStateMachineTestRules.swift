import Foundation
import Testing

@testable import PremiseCore
@testable import PremiseTesting
@testable import PremiseStrategies
func addCounterRules(to machine: inout RuleBasedStateMachine<CounterMachine>) {
  machine.rule(
    "increment",
    argument: Strategy<Int>.integers(in: 1...3)
  ) { state, amount in
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
}
func addIsolationRules(
  to machine: inout RuleBasedStateMachine<BundleIsolationMachine>,
  first: StateMachineBundle<Int>,
  second: StateMachineBundle<Int>
) {
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
    { _, _ in throw StateMachineTestError.bundleLeak }
  )
}
func addEmptyBundleRules(
  to machine: inout RuleBasedStateMachine<EmptyBundleMachine>,
  ids: StateMachineBundle<Int>
) {
  machine.rule(
    "consume empty",
    argument: ids.strategy(),
    precondition: { !$0.created },
    { _, _ in throw StateMachineTestError.bundleLeak }
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
  addEmptyBundleConsumer(to: &machine, ids: ids)
}

private func addEmptyBundleConsumer(
  to machine: inout RuleBasedStateMachine<EmptyBundleMachine>,
  ids: StateMachineBundle<Int>
) {
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
}
func addConsumingBundleRules(
  to machine: inout RuleBasedStateMachine<PhaseMachine>,
  ids: StateMachineBundle<Int>
) {
  machine.rule(
    "create",
    argument: Strategy<Int>.just(7),
    precondition: { $0.phase == 0 },
    target: ids,
    { state, value in
      state.phase = 1
      return value
    }
  )
  machine.rule(
    "consume",
    argument: ids.consumingStrategy(),
    precondition: { $0.phase == 1 },
    { state, value in
      state.phase = 2
      state.consumed.append(value)
    }
  )
  addSecondConsumingRule(to: &machine, ids: ids)
}

private func addSecondConsumingRule(
  to machine: inout RuleBasedStateMachine<PhaseMachine>,
  ids: StateMachineBundle<Int>
) {
  machine.rule(
    "consume again",
    argument: ids.consumingStrategy(),
    precondition: { $0.phase == 2 },
    { _, _ in throw StateMachineTestError.bundleLeak }
  )
}
func addMultipleOutputRules(
  to machine: inout RuleBasedStateMachine<PhaseMachine>,
  ids: StateMachineBundle<Int>,
  labels: StateMachineBundle<String>
) {
  machine.rule(
    "create pair",
    argument: Strategy<Int>.just(3),
    precondition: { $0.phase == 0 },
    targets: (ids, labels),
    { state, value in
      state.phase = 1
      return (value, "id-\(value)")
    }
  )
  machine.rule(
    "consume id",
    argument: ids.strategy(),
    precondition: { $0.phase == 1 },
    { state, value in
      state.consumed.append(value)
      state.phase = 2
    }
  )
  addLabelConsumer(to: &machine, labels: labels)
}

private func addLabelConsumer(
  to machine: inout RuleBasedStateMachine<PhaseMachine>,
  labels: StateMachineBundle<String>
) {
  machine.rule(
    "consume label",
    argument: labels.strategy(),
    precondition: { $0.phase == 2 },
    { state, value in
      state.text.append(value)
      state.phase = 3
    }
  )
}
