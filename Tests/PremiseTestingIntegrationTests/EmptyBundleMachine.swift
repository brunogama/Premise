struct EmptyBundleMachine: Sendable {
  let recorder: RuleRecorder
  var created = false
  var consumed = false
}
