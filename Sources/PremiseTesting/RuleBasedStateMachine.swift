import PremiseCore

/// Execution knobs for rule-based state machine checks.
public struct StateMachineConfig: Sendable {
  /// Number of independent examples to execute.
  public var maxExamples: Int
  /// Maximum number of rule steps to execute in each example.
  public var maxSteps: Int
  /// Optional deterministic base seed for generated examples.
  public var seed: UInt64?
  /// Maximum number of primitive draws available to each example.
  public var maxDrawsPerExample: Int

  /// Creates a configuration for rule-based state machine checks.
  public init(
    maxExamples: Int = 100,
    maxSteps: Int = 50,
    seed: UInt64? = nil,
    maxDrawsPerExample: Int = 10_000
  ) {
    precondition(maxExamples >= 0, "maxExamples must be non-negative")
    precondition(maxSteps >= 0, "maxSteps must be non-negative")
    precondition(maxDrawsPerExample >= 0, "maxDrawsPerExample must be non-negative")
    self.maxExamples = maxExamples
    self.maxSteps = maxSteps
    self.seed = seed
    self.maxDrawsPerExample = maxDrawsPerExample
  }
}

/// Error raised when a rule-based state machine check fails.
public struct StateMachineFailure: Error, Sendable, CustomStringConvertible {
  /// The state machine phase that produced the failure.
  public enum Phase: Sendable, Equatable, CustomStringConvertible {
    /// The fresh-state factory threw before an example started.
    case stateFactory
    /// A rule precondition threw while filtering enabled rules.
    case precondition
    /// A rule failed while drawing its argument or executing its body.
    case rule
    /// An invariant failed before a run or after a rule step.
    case invariant

    /// Human-readable phase name.
    public var description: String {
      switch self {
      case .stateFactory: return "stateFactory"
      case .precondition: return "precondition"
      case .rule: return "rule"
      case .invariant: return "invariant"
      }
    }
  }

  /// Base seed for the full state-machine check.
  public let baseSeed: UInt64
  /// Zero-based generated example index.
  public let exampleIndex: Int
  /// Zero-based step index, or `-1` before any step has run.
  public let step: Int
  /// Phase that produced the failure.
  public let phase: Phase
  /// Rule name when the failure is associated with a rule.
  public let ruleName: String?
  /// Invariant name when the failure is associated with an invariant.
  public let invariantName: String?
  /// String form of the underlying error.
  public let underlyingDescription: String

  init(
    baseSeed: UInt64,
    exampleIndex: Int,
    step: Int,
    phase: Phase,
    ruleName: String? = nil,
    invariantName: String? = nil,
    underlyingDescription: String
  ) {
    self.baseSeed = baseSeed
    self.exampleIndex = exampleIndex
    self.step = step
    self.phase = phase
    self.ruleName = ruleName
    self.invariantName = invariantName
    self.underlyingDescription = underlyingDescription
  }

  /// Human-readable failure description with reproduction metadata.
  public var description: String {
    var parts = [
      "Rule-based state machine failed",
      "baseSeed=\(baseSeed)",
      "exampleIndex=\(exampleIndex)",
      "step=\(step)",
      "phase=\(phase)",
    ]
    if let ruleName {
      parts.append("rule=\(ruleName)")
    }
    if let invariantName {
      parts.append("invariant=\(invariantName)")
    }
    parts.append("underlying=\(underlyingDescription)")
    return parts.joined(separator: ", ")
  }
}

/// A per-run collection of values produced by one rule and consumed by others.
public struct StateMachineBundle<Element: Sendable>: Sendable {
  /// Human-readable bundle name used in strategy labels.
  public let label: String
  fileprivate let key: StateMachineBundleKey

  /// Creates a bundle whose values are scoped to a single generated example.
  public init(_ label: String) {
    self.label = label
    key = StateMachineBundleKey(token: StateMachineBundleToken(label: label))
  }

  /// Returns a strategy that draws from values saved to this bundle in the current run.
  public func strategy() -> Strategy<Element> {
    let key = key
    let label = label
    return Strategy<Element>(
      label: "stateMachineBundle(\(label))",
      draw: { data in
        guard let context = StateMachineBundleScope.current else {
          throw StrategyError.assumptionFailed(label: label, maxAttempts: 1)
        }

        let values: [Element] = context.values(for: key)
        guard !values.isEmpty else {
          throw StrategyError.assumptionFailed(label: label, maxAttempts: 1)
        }

        let index = data.drawInteger(in: 0...(values.count - 1))
        return values[index]
      }
    )
  }
}

/// A rule-based model where generated operations mutate shared test state.
public struct RuleBasedStateMachine<State: Sendable>: Sendable {
  fileprivate let makeInitialState: @Sendable () async throws -> State
  fileprivate var rules: [StateMachineRule<State>]
  fileprivate var invariants: [StateMachineInvariant<State>]

  /// Creates an empty state machine with a value-state convenience initializer.
  public init(initialState: State) {
    makeInitialState = { initialState }
    rules = []
    invariants = []
  }

  /// Creates an empty state machine with a fresh state factory per example.
  public init(
    makeInitialState: @escaping @Sendable () async throws -> State
  ) {
    self.makeInitialState = makeInitialState
    rules = []
    invariants = []
  }

  /// Adds a rule that draws an argument and mutates the state when enabled.
  public mutating func rule<Argument: Sendable>(
    _ name: String,
    argument: Strategy<Argument>,
    precondition: @escaping @Sendable (State) async throws -> Bool = { _ in true },
    _ body: @escaping @Sendable (inout State, Argument) async throws -> Void
  ) {
    rules.append(
      StateMachineRule(
        name: name,
        isEnabled: precondition,
        run: { state, context, data in
          guard let argument = try draw(argument, using: &data, context: context) else {
            return false
          }

          try await body(&state, argument)
          return true
        }
      )
    )
  }

  /// Adds a rule that saves its result into a bundle for later rules.
  public mutating func rule<Argument: Sendable, Element: Sendable>(
    _ name: String,
    argument: Strategy<Argument>,
    precondition: @escaping @Sendable (State) async throws -> Bool = { _ in true },
    target: StateMachineBundle<Element>,
    _ body: @escaping @Sendable (inout State, Argument) async throws -> Element
  ) {
    rules.append(
      StateMachineRule(
        name: name,
        isEnabled: precondition,
        run: { state, context, data in
          guard let argument = try draw(argument, using: &data, context: context) else {
            return false
          }

          let element = try await body(&state, argument)
          context.append(element, to: target)
          return true
        }
      )
    )
  }

  /// Adds an invariant checked before any rule and after every executed rule.
  public mutating func invariant(
    _ name: String,
    _ check: @escaping @Sendable (State) async throws -> Void
  ) {
    invariants.append(StateMachineInvariant(name: name, check: check))
  }
}

/// Runs the given machine for several generated examples.
public func checkRuleBasedStateMachine<State: Sendable>(
  _ machine: RuleBasedStateMachine<State>,
  config: StateMachineConfig = StateMachineConfig()
) async throws {
  let baseSeed = config.seed ?? UInt64.random(in: .min ... .max)
  for exampleIndex in 0..<config.maxExamples {
    let seed = baseSeed &+ UInt64(exampleIndex)
    let metadata = StateMachineRunMetadata(
      baseSeed: baseSeed,
      exampleIndex: exampleIndex
    )
    try await runOnce(machine, config: config, seed: seed, metadata: metadata)
  }
}

private func runOnce<State: Sendable>(
  _ machine: RuleBasedStateMachine<State>,
  config: StateMachineConfig,
  seed: UInt64,
  metadata: StateMachineRunMetadata
) async throws {
  var state: State
  do {
    state = try await machine.makeInitialState()
  } catch {
    throw stateMachineFailure(
      wrapping: error,
      metadata: metadata,
      step: -1,
      phase: .stateFactory
    )
  }

  var context = StateMachineRunContext()
  let provider = PseudoRandomProvider(seed: seed, maxDraws: config.maxDrawsPerExample)
  var data = PremiseData(provider: provider)

  try await checkInvariants(machine.invariants, state: state, metadata: metadata, step: -1)
  for step in 0..<config.maxSteps {
    let executed = try await executeStep(
      rules: machine.rules,
      state: &state,
      context: &context,
      data: &data,
      metadata: metadata,
      step: step
    )
    guard executed else { return }
    try await checkInvariants(machine.invariants, state: state, metadata: metadata, step: step)
  }
}

private func executeStep<State: Sendable>(
  rules: [StateMachineRule<State>],
  state: inout State,
  context: inout StateMachineRunContext,
  data: inout PremiseData,
  metadata: StateMachineRunMetadata,
  step: Int
) async throws -> Bool {
  let enabled = try await enabledRules(
    rules,
    state: state,
    metadata: metadata,
    step: step
  )
  guard !enabled.isEmpty else { return false }

  let startIndex = data.drawInteger(in: 0...(enabled.count - 1))
  for offset in enabled.indices {
    let index = (startIndex + offset) % enabled.count
    let rule = enabled[index]
    do {
      if try await rule.run(&state, &context, &data) {
        return true
      }
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

  return false
}

private func enabledRules<State: Sendable>(
  _ rules: [StateMachineRule<State>],
  state: State,
  metadata: StateMachineRunMetadata,
  step: Int
) async throws -> [StateMachineRule<State>] {
  var enabled: [StateMachineRule<State>] = []
  enabled.reserveCapacity(rules.count)
  for rule in rules {
    do {
      if try await rule.isEnabled(state) {
        enabled.append(rule)
      }
    } catch {
      throw stateMachineFailure(
        wrapping: error,
        metadata: metadata,
        step: step,
        phase: .precondition,
        ruleName: rule.name
      )
    }
  }
  return enabled
}

private func checkInvariants<State: Sendable>(
  _ invariants: [StateMachineInvariant<State>],
  state: State,
  metadata: StateMachineRunMetadata,
  step: Int
) async throws {
  for invariant in invariants {
    do {
      try await invariant.check(state)
    } catch {
      throw stateMachineFailure(
        wrapping: error,
        metadata: metadata,
        step: step,
        phase: .invariant,
        invariantName: invariant.name
      )
    }
  }
}

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
    case .filterExhausted, .assumptionFailed:
      return nil
    @unknown default:
      throw error
    }
  } catch {
    throw error
  }
}

private struct StateMachineRule<State: Sendable>: Sendable {
  var name: String
  var isEnabled: @Sendable (State) async throws -> Bool
  var run:
    @Sendable (
      inout State,
      inout StateMachineRunContext,
      inout PremiseData
    ) async throws -> Bool
}

private struct StateMachineInvariant<State: Sendable>: Sendable {
  var name: String
  var check: @Sendable (State) async throws -> Void
}

private struct StateMachineRunMetadata: Sendable {
  var baseSeed: UInt64
  var exampleIndex: Int
}

private func stateMachineFailure(
  wrapping error: any Error,
  metadata: StateMachineRunMetadata,
  step: Int,
  phase: StateMachineFailure.Phase,
  ruleName: String? = nil,
  invariantName: String? = nil
) -> StateMachineFailure {
  if let failure = error as? StateMachineFailure {
    return failure
  }

  return StateMachineFailure(
    baseSeed: metadata.baseSeed,
    exampleIndex: metadata.exampleIndex,
    step: step,
    phase: phase,
    ruleName: ruleName,
    invariantName: invariantName,
    underlyingDescription: String(describing: error)
  )
}

private struct StateMachineRunContext: Sendable {
  private var storage: [StateMachineBundleKey: [any Sendable]] = [:]

  func values<Element: Sendable>(for key: StateMachineBundleKey) -> [Element] {
    guard let values = storage[key] else { return [] }
    return values.compactMap { $0 as? Element }
  }

  mutating func append<Element: Sendable>(
    _ element: Element,
    to bundle: StateMachineBundle<Element>
  ) {
    storage[bundle.key, default: []].append(element)
  }
}

private enum StateMachineBundleScope {
  @TaskLocal static var current: StateMachineRunContext?
}

private struct StateMachineBundleKey: Hashable, Sendable {
  private let token: StateMachineBundleToken

  init(token: StateMachineBundleToken) {
    self.token = token
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.token === rhs.token
  }

  func hash(into hasher: inout Hasher) {
    ObjectIdentifier(token).hash(into: &hasher)
  }
}

private final class StateMachineBundleToken: Sendable {
  let label: String

  init(label: String) {
    self.label = label
  }
}
