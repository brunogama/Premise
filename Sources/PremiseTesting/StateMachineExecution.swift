import PremiseCore

struct StateMachineExecution<State: Sendable> {
  let machine: RuleBasedStateMachine<State>
  let config: StateMachineConfig
  let metadata: StateMachineRunMetadata
  let context = StateMachineRunContext()
  var state: State
  var data: PremiseData
  var program = StateMachineProgram()

  mutating func run() async throws {
    do {
      try await execute()
    } catch let failure as StateMachineFailure {
      if failure.phase != .teardown { try? await teardown() }
      throw failure.with(
        replayTrace: data.snapshot(),
        program: program,
        shrinkCount: failure.shrinkCount
      )
    } catch {
      try? await teardown()
      throw stateMachineFailure(
        wrapping: error,
        metadata: metadata,
        step: program.steps.last?.index ?? -1,
        phase: .rule
      ).with(replayTrace: data.snapshot(), program: program, shrinkCount: 0)
    }
  }

  private mutating func execute() async throws {
    try await check(step: -1, duringInit: true)
    try await initialize()
    try await check(step: -1, duringInit: false)
    for step in 0..<config.maxSteps {
      guard try await executeStep(step) else { break }
      try await check(step: step, duringInit: false)
    }
    try await teardown()
  }

  private func check(step: Int, duringInit: Bool) async throws {
    try await checkInvariants(
      machine.invariants,
      state: state,
      metadata: metadata,
      step: step,
      duringInit: duringInit
    )
  }

  private mutating func teardown() async throws {
    try await executeTeardowns(
      machine.teardowns,
      state: &state,
      metadata: metadata
    )
  }

  private mutating func initialize() async throws {
    for (index, rule) in machine.initializers.enumerated() {
      do {
        try await initialize(rule, step: index - machine.initializers.count)
      } catch {
        throw stateMachineFailure(
          wrapping: error,
          metadata: metadata,
          step: -1,
          phase: .initialize,
          ruleName: rule.name
        )
      }
    }
  }

  private mutating func initialize(
    _ rule: StateMachineRule<State>,
    step: Int
  ) async throws {
    guard try await rule.isEnabled(state) else { return }
    guard let result = try await rule.run(&state, context, &data) else {
      return
    }
    program.steps.append(result.programStep(index: step))
    try await check(step: step, duringInit: true)
  }

  private mutating func executeStep(_ step: Int) async throws -> Bool {
    let enabled = try await enabledRules(
      machine.rules,
      state: state,
      metadata: metadata,
      step: step
    )
    guard !enabled.isEmpty else { return false }
    let start = data.drawInteger(in: 0...(enabled.count - 1))
    for offset in enabled.indices {
      let rule = enabled[(start + offset) % enabled.count]
      if try await execute(rule, step: step) { return true }
    }
    return false
  }

  private mutating func execute(
    _ rule: StateMachineRule<State>,
    step: Int
  ) async throws -> Bool {
    do {
      guard let result = try await rule.run(&state, context, &data) else {
        return false
      }
      program.steps.append(result.programStep(index: step))
      return true
    } catch {
      throw stateMachineFailure(
        wrapping: error,
        metadata: metadata,
        step: step,
        phase: .rule,
        ruleName: rule.name
      )
    }
  }
}

private extension StateMachineStepExecution {
  func programStep(index: Int) -> StateMachineProgramStep {
    StateMachineProgramStep(
      index: index,
      ruleName: ruleName,
      argumentDescription: argumentDescription,
      outputs: outputs
    )
  }
}
