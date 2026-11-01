import PremiseCore

/// A rule-based model where generated operations mutate shared test state.
public struct RuleBasedStateMachine<State: Sendable>: Sendable {
  let makeInitialState: @Sendable () async throws -> State
  var initializers: [StateMachineRule<State>]
  var rules: [StateMachineRule<State>]
  var invariants: [StateMachineInvariant<State>]
  var teardowns: [StateMachineTeardown<State>]

  /// Creates an empty state machine with a value-state convenience initializer.
  public init(initialState: State) {
    makeInitialState = { initialState }
    initializers = []
    rules = []
    invariants = []
    teardowns = []
  }

  /// Creates an empty state machine with a fresh state factory per example.
  public init(
    makeInitialState: @escaping @Sendable () async throws -> State
  ) {
    self.makeInitialState = makeInitialState
    initializers = []
    rules = []
    invariants = []
    teardowns = []
  }

}

extension RuleBasedStateMachine {
  // Preserve the published initializer rule signature.
  // swiftlint:disable function_parameter_count
  /// Adds an initialization rule that runs before normal rules.
  public mutating func initialize<Argument: Sendable>(
    _ name: String,
    argument: Strategy<Argument>,
    precondition: @escaping @Sendable (State) async throws -> Bool = {
      _ in true
    },
    _ body: @escaping @Sendable (inout State, Argument) async throws -> Void
  ) {
    // swiftlint:enable function_parameter_count
    initializers.append(
      makeRule(
        StateMachineRuleInput(
          source: StateMachineRuleSource(name: name, argument: argument),
          precondition: precondition
        ),
        body
      )
    )
  }

  // Preserve the published bundled initializer signature.
  // swiftlint:disable function_parameter_count
  /// Adds an initialization rule that saves its result into a bundle.
  public mutating func initialize<Argument: Sendable, Element: Sendable>(
    _ name: String,
    argument: Strategy<Argument>,
    precondition: @escaping @Sendable (State) async throws -> Bool = {
      _ in true
    },
    target: StateMachineBundle<Element>,
    _ body: @escaping @Sendable (inout State, Argument) async throws -> Element
  ) {
    // swiftlint:enable function_parameter_count
    initializers.append(
      makeRule(
        StateMachineRuleInput(
          source: StateMachineRuleSource(name: name, argument: argument),
          precondition: precondition
        ),
        target: target,
        body
      )
    )
  }

  // Preserve the published rule signature.
  // swiftlint:disable function_parameter_count
  /// Adds a rule that draws an argument and mutates the state when enabled.
  public mutating func rule<Argument: Sendable>(
    _ name: String,
    argument: Strategy<Argument>,
    precondition: @escaping @Sendable (State) async throws -> Bool = {
      _ in true
    },
    _ body: @escaping @Sendable (inout State, Argument) async throws -> Void
  ) {
    // swiftlint:enable function_parameter_count
    rules.append(
      makeRule(
        StateMachineRuleInput(
          source: StateMachineRuleSource(name: name, argument: argument),
          precondition: precondition
        ),
        body
      )
    )
  }

  // Preserve the published bundled rule signature.
  // swiftlint:disable function_parameter_count
  /// Adds a rule that saves its result into a bundle for later rules.
  public mutating func rule<Argument: Sendable, Element: Sendable>(
    _ name: String,
    argument: Strategy<Argument>,
    precondition: @escaping @Sendable (State) async throws -> Bool = {
      _ in true
    },
    target: StateMachineBundle<Element>,
    _ body: @escaping @Sendable (inout State, Argument) async throws -> Element
  ) {
    // swiftlint:enable function_parameter_count
    rules.append(
      makeRule(
        StateMachineRuleInput(
          source: StateMachineRuleSource(name: name, argument: argument),
          precondition: precondition
        ),
        target: target,
        body
      )
    )
  }

  // Preserve the published multi-output rule signature.
  // swiftlint:disable function_parameter_count
  /// Adds a rule that saves multiple outputs into bundles.
  public mutating func rule<
    Argument: Sendable,
    First: Sendable,
    Second: Sendable
  >(
    _ name: String,
    argument: Strategy<Argument>,
    precondition: @escaping @Sendable (State) async throws -> Bool = {
      _ in true
    },
    targets: (StateMachineBundle<First>, StateMachineBundle<Second>),
    _ body:
      @escaping @Sendable (inout State, Argument) async throws -> (
        First, Second
      )
  ) {
    // swiftlint:enable function_parameter_count
    rules.append(
      makeRule(
        StateMachineRuleInput(
          source: StateMachineRuleSource(name: name, argument: argument),
          precondition: precondition
        ),
        targets: targets,
        body
      )
    )
  }

  /// Adds an invariant checked before initialization and after each rule.
  public mutating func invariant(
    _ name: String,
    checkDuringInit: Bool = true,
    _ check: @escaping @Sendable (State) async throws -> Void
  ) {
    invariants.append(
      StateMachineInvariant(
        name: name,
        checkDuringInit: checkDuringInit,
        check: check
      )
    )
  }

  /// Adds a teardown action run after normal rule execution.
  public mutating func teardown(
    _ name: String = "teardown",
    _ body: @escaping @Sendable (inout State) async throws -> Void
  ) {
    teardowns.append(StateMachineTeardown(name: name, body: body))
  }
}
