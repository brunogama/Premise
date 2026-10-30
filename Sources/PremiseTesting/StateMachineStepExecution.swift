struct StateMachineStepExecution: Sendable {
  var ruleName: String
  var argumentDescription: String
  var outputs: [String] = []
}
