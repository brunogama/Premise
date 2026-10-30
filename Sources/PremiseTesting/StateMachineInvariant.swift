struct StateMachineInvariant<State: Sendable>: Sendable {
  var name: String
  var checkDuringInit: Bool
  var check: @Sendable (State) async throws -> Void
}
