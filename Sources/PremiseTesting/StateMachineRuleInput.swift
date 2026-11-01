struct StateMachineRuleInput<State: Sendable, Argument: Sendable>: Sendable {
  let source: StateMachineRuleSource<Argument>
  let precondition: @Sendable (State) async throws -> Bool
}
