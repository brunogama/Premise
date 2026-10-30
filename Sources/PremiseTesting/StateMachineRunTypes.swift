import PremiseCore

struct StateMachineRule<State: Sendable>: Sendable {
  var name: String
  var isEnabled: @Sendable (State) async throws -> Bool
  var run:
    @Sendable (
      inout State,
      StateMachineRunContext,
      inout PremiseData
    ) async throws -> StateMachineStepExecution?
}
