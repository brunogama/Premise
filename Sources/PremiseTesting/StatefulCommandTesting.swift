// Preserve this public signature for source compatibility.
// swiftlint:disable function_parameter_count
/// Runs stateful commands against a lightweight model and a system under test.
public func checkStateMachine<Command: StatefulCommand>(
  commands: [Command],
  initialModel: Command.Model,
  makeSystem: @escaping @Sendable () async throws -> Command.System,
  assertEquivalent:
    @escaping @Sendable (Command.Model, Command.System) async throws ->
    Void
) async throws {
  // swiftlint:enable function_parameter_count
  var model = initialModel
  let system = try await makeSystem()
  try await assertEquivalent(model, system)

  for command in commands where command.canApply(to: model) {
    switch command.expectation {
    case .succeeds:
      model = try await runSuccessful(command, model: model, system: system)
      try await assertEquivalent(model, system)
    case .fails:
      try await runExpectedFailure(command, system: system)
      try await assertEquivalent(model, system)
    }
  }
}


private func runSuccessful<Command: StatefulCommand>(
  _ command: Command,
  model: Command.Model,
  system: Command.System
) async throws -> Command.Model {
  var nextModel = model
  try command.apply(to: &nextModel)
  do {
    try await command.run(on: system)
  } catch {
    throw StatefulCommandExpectationError(
      commandLabel: command.label,
      expectation: .succeeds,
      underlyingDescription: String(describing: error)
    )
  }
  return nextModel
}

private func runExpectedFailure<Command: StatefulCommand>(
  _ command: Command,
  system: Command.System
) async throws {
  do {
    try await command.run(on: system)
  } catch {
    return
  }
  throw StatefulCommandExpectationError(
    commandLabel: command.label,
    expectation: .fails
  )
}
