struct PhaseMachine: Sendable {
  var initialized = false
  var phase = 0
  var consumed: [Int] = []
  var text: [String] = []
  let recorder: RuleRecorder?
}
