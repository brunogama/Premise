import PremiseCore

private func draw<Value: Sendable>(
  _ strategy: Strategy<Value>,
  using data: inout PremiseData,
  context: StateMachineRunContext
) throws -> Value? {
  do {
    return try StateMachineBundleScope.$current.withValue(context) {
      try strategy.draw(&data)
    }
  } catch let error as StrategyError {
    switch error {
    case .filterExhausted, .assumptionFailed, .noExamples:
      return nil
    case .invalidRegex:
      throw error
    @unknown default:
      throw error
    }
  } catch {
    throw error
  }
}

private func draw<Value: Sendable>(
  _ source: StateMachineRuleSource<Value>,
  using data: inout PremiseData,
  context: StateMachineRunContext
) throws -> Value? {
  try data.withSpan(source.name) { spanData in
    try draw(source.argument, using: &spanData, context: context)
  }
}
func makeRule<State: Sendable, Argument: Sendable>(
  _ input: StateMachineRuleInput<State, Argument>,
  _ body: @escaping @Sendable (inout State, Argument) async throws -> Void
) -> StateMachineRule<State> {
  StateMachineRule(
    name: input.source.name,
    isEnabled: input.precondition,
    run: { state, context, data in
      guard
        let value = try draw(input.source, using: &data, context: context)
      else {
        return nil
      }

      try await body(&state, value)
      return StateMachineStepExecution(
        ruleName: input.source.name,
        argumentDescription: String(describing: value)
      )
    }
  )
}

func makeRule<State: Sendable, Argument: Sendable, Element: Sendable>(
  _ input: StateMachineRuleInput<State, Argument>,
  target: StateMachineBundle<Element>,
  _ body: @escaping @Sendable (inout State, Argument) async throws -> Element
) -> StateMachineRule<State> {
  StateMachineRule(
    name: input.source.name,
    isEnabled: input.precondition,
    run: { state, context, data in
      guard
        let value = try draw(input.source, using: &data, context: context)
      else {
        return nil
      }

      let element = try await body(&state, value)
      context.append(element, to: target)
      return StateMachineStepExecution(
        ruleName: input.source.name,
        argumentDescription: String(describing: value),
        outputs: ["\(target.label)=\(String(describing: element))"]
      )
    }
  )
}

func makeRule<
  State: Sendable,
  Argument: Sendable,
  First: Sendable,
  Second: Sendable
>(
  _ input: StateMachineRuleInput<State, Argument>,
  targets: (StateMachineBundle<First>, StateMachineBundle<Second>),
  _ body:
    @escaping @Sendable (inout State, Argument) async throws -> (
      First, Second
    )
) -> StateMachineRule<State> {
  StateMachineRule(
    name: input.source.name,
    isEnabled: input.precondition,
    run: { state, context, data in
      guard
        let value = try draw(input.source, using: &data, context: context)
      else { return nil }

      let output = try await body(&state, value)
      context.append(output.0, to: targets.0)
      context.append(output.1, to: targets.1)
      return StateMachineStepExecution(
        ruleName: input.source.name,
        argumentDescription: String(describing: value),
        outputs: [
          "\(targets.0.label)=\(String(describing: output.0))",
          "\(targets.1.label)=\(String(describing: output.1))",
        ]
      )
    }
  )
}
