import PremiseCore

struct StateMachineRuleSource<Argument: Sendable>: Sendable {
  let name: String
  let argument: Strategy<Argument>
}
