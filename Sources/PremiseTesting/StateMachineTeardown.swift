struct StateMachineTeardown<State: Sendable>: Sendable {
  var name: String
  var body: @Sendable (inout State) async throws -> Void
}
