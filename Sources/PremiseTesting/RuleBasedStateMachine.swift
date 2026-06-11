import Foundation
import PremiseCore
import PremiseDatabase

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
  /// Whether replay traces should run before fresh generation.
  public var replayEnabled: Bool
  /// Stable identity used for persistence and replay artifacts.
  public var propertyID: PropertyIdentity
  /// Additional replay traces supplied directly by callers.
  public var replayTraces: [ChoiceTrace]
  /// Directory used to persist failing state-machine traces.
  public var localDatabaseDirectory: URL?
  /// Directory where JSON trace artifacts should be exported.
  public var traceExportDirectory: URL?
  /// Maximum trace-shrink attempts after a state-machine failure.
  public var maxShrinkIterations: Int

  /// Creates a configuration for rule-based state machine checks.
  public init(
    maxExamples: Int = 100,
    maxSteps: Int = 50,
    seed: UInt64? = nil,
    maxDrawsPerExample: Int = 10_000,
    replayEnabled: Bool = true,
    propertyID: PropertyIdentity = PropertyIdentity(
      fileID: "state-machine",
      line: 0,
      strategyLabel: "rule-based-state-machine"
    ),
    replayTraces: [ChoiceTrace] = [],
    localDatabaseDirectory: URL? = nil,
    traceExportDirectory: URL? = nil,
    maxShrinkIterations: Int = 100
  ) {
    precondition(maxExamples >= 0, "maxExamples must be non-negative")
    precondition(maxSteps >= 0, "maxSteps must be non-negative")
    precondition(maxDrawsPerExample >= 0, "maxDrawsPerExample must be non-negative")
    precondition(maxShrinkIterations >= 0, "maxShrinkIterations must be non-negative")
    self.maxExamples = maxExamples
    self.maxSteps = maxSteps
    self.seed = seed
    self.maxDrawsPerExample = maxDrawsPerExample
    self.replayEnabled = replayEnabled
    self.propertyID = propertyID
    self.replayTraces = replayTraces
    self.localDatabaseDirectory = localDatabaseDirectory
    self.traceExportDirectory = traceExportDirectory
    self.maxShrinkIterations = maxShrinkIterations
  }

  /// Adds directly supplied replay traces.
  public func replaying(_ traces: [ChoiceTrace]) -> Self {
    var copy = self
    copy.replayTraces += traces
    return copy
  }

  /// Sets the writable local failure database directory.
  public func storingFailures(in directory: URL) -> Self {
    var copy = self
    copy.localDatabaseDirectory = directory
    return copy
  }

  /// Sets the directory where JSON trace artifacts are written.
  public func exportingFailureTraces(to directory: URL) -> Self {
    var copy = self
    copy.traceExportDirectory = directory
    return copy
  }

  /// Sets the maximum state-machine shrink attempts.
  public func shrinkIterations(_ count: Int) -> Self {
    var copy = self
    copy.maxShrinkIterations = count
    return copy
  }
}

/// A printable state-machine program step produced by a rule execution.
public struct StateMachineProgramStep: Sendable, Codable, Equatable, CustomStringConvertible {
  /// Zero-based step index in the generated program.
  public let index: Int
  /// Name of the executed rule.
  public let ruleName: String
  /// Drawn argument rendered for diagnostics.
  public let argumentDescription: String
  /// Bundle outputs rendered for diagnostics.
  public let outputs: [String]

  public init(
    index: Int,
    ruleName: String,
    argumentDescription: String,
    outputs: [String] = []
  ) {
    self.index = index
    self.ruleName = ruleName
    self.argumentDescription = argumentDescription
    self.outputs = outputs
  }

  public var description: String {
    let outputSuffix = outputs.isEmpty ? "" : " -> \(outputs.joined(separator: ", "))"
    return "\(index). \(ruleName)(\(argumentDescription))\(outputSuffix)"
  }
}

/// A minimal printable program for a state-machine failure.
public struct StateMachineProgram: Sendable, Codable, Equatable, CustomStringConvertible {
  /// Executed steps in order.
  public var steps: [StateMachineProgramStep]

  public init(steps: [StateMachineProgramStep] = []) {
    self.steps = steps
  }

  public var description: String {
    guard !steps.isEmpty else { return "<empty program>" }
    return steps.map(\.description).joined(separator: "\n")
  }
}

/// Error raised when a rule-based state machine check fails.
public struct StateMachineFailure: Error, Sendable, CustomStringConvertible {
  /// The state machine phase that produced the failure.
  public enum Phase: Sendable, Equatable, CustomStringConvertible {
    /// The fresh-state factory threw before an example started.
    case stateFactory
    /// An initialize rule failed.
    case initialize
    /// A rule precondition threw while filtering enabled rules.
    case precondition
    /// A rule failed while drawing its argument or executing its body.
    case rule
    /// An invariant failed before a run, during initialization, or after a rule step.
    case invariant
    /// A teardown action failed after a run.
    case teardown

    /// Human-readable phase name.
    public var description: String {
      switch self {
      case .stateFactory: return "stateFactory"
      case .initialize: return "initialize"
      case .precondition: return "precondition"
      case .rule: return "rule"
      case .invariant: return "invariant"
      case .teardown: return "teardown"
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
  /// Replay trace for the failing state-machine program.
  public let replayTrace: ChoiceTrace
  /// Printable minimal failing program.
  public let program: StateMachineProgram
  /// Number of successful shrink steps applied to the replay trace.
  public let shrinkCount: Int

  init(
    baseSeed: UInt64,
    exampleIndex: Int,
    step: Int,
    phase: Phase,
    ruleName: String? = nil,
    invariantName: String? = nil,
    underlyingDescription: String,
    replayTrace: ChoiceTrace = ChoiceTrace(),
    program: StateMachineProgram = StateMachineProgram(),
    shrinkCount: Int = 0
  ) {
    self.baseSeed = baseSeed
    self.exampleIndex = exampleIndex
    self.step = step
    self.phase = phase
    self.ruleName = ruleName
    self.invariantName = invariantName
    self.underlyingDescription = underlyingDescription
    self.replayTrace = replayTrace
    self.program = program
    self.shrinkCount = shrinkCount
  }

  /// Human-readable failure description with reproduction metadata.
  public var description: String {
    var parts = [
      "Rule-based state machine failed",
      "baseSeed=\(baseSeed)",
      "exampleIndex=\(exampleIndex)",
      "step=\(step)",
      "phase=\(phase)",
      "shrinks=\(shrinkCount)",
    ]
    if let ruleName {
      parts.append("rule=\(ruleName)")
    }
    if let invariantName {
      parts.append("invariant=\(invariantName)")
    }
    parts.append("traceEntries=\(replayTrace.entries.count)")
    parts.append("underlying=\(underlyingDescription)")
    parts.append("program=\n\(program.description)")
    return parts.joined(separator: ", ")
  }

  fileprivate func with(
    replayTrace: ChoiceTrace,
    program: StateMachineProgram,
    shrinkCount: Int
  ) -> Self {
    StateMachineFailure(
      baseSeed: baseSeed,
      exampleIndex: exampleIndex,
      step: step,
      phase: phase,
      ruleName: ruleName,
      invariantName: invariantName,
      underlyingDescription: underlyingDescription,
      replayTrace: replayTrace,
      program: program,
      shrinkCount: shrinkCount
    )
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
    strategy(consuming: false)
  }

  /// Returns a strategy that draws and removes a saved bundle value.
  public func consumingStrategy() -> Strategy<Element> {
    strategy(consuming: true)
  }

  /// Returns a bundle strategy, optionally consuming selected values.
  public func strategy(consuming: Bool) -> Strategy<Element> {
    let key = key
    let label = label
    return Strategy<Element>(
      label: consuming ? "stateMachineBundle(\(label), consuming)" : "stateMachineBundle(\(label))",
      draw: { data in
        guard let context = StateMachineBundleScope.current else {
          throw StrategyError.assumptionFailed(label: label, maxAttempts: 1)
        }

        let values: [Element] = context.values(for: key)
        guard !values.isEmpty else {
          throw StrategyError.assumptionFailed(label: label, maxAttempts: 1)
        }

        let index = data.drawInteger(in: 0...(values.count - 1))
        if consuming {
          return context.removeValue(at: index, for: key) ?? values[index]
        }
        return values[index]
      }
    )
  }
}

/// A rule-based model where generated operations mutate shared test state.
public struct RuleBasedStateMachine<State: Sendable>: Sendable {
  fileprivate let makeInitialState: @Sendable () async throws -> State
  fileprivate var initializers: [StateMachineRule<State>]
  fileprivate var rules: [StateMachineRule<State>]
  fileprivate var invariants: [StateMachineInvariant<State>]
  fileprivate var teardowns: [StateMachineTeardown<State>]

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

  /// Adds an initialization rule that runs before normal rules.
  public mutating func initialize<Argument: Sendable>(
    _ name: String,
    argument: Strategy<Argument>,
    precondition: @escaping @Sendable (State) async throws -> Bool = { _ in true },
    _ body: @escaping @Sendable (inout State, Argument) async throws -> Void
  ) {
    initializers.append(
      makeRule(name: name, argument: argument, precondition: precondition, body)
    )
  }

  /// Adds an initialization rule that saves its result into a bundle.
  public mutating func initialize<Argument: Sendable, Element: Sendable>(
    _ name: String,
    argument: Strategy<Argument>,
    precondition: @escaping @Sendable (State) async throws -> Bool = { _ in true },
    target: StateMachineBundle<Element>,
    _ body: @escaping @Sendable (inout State, Argument) async throws -> Element
  ) {
    initializers.append(
      makeRule(name: name, argument: argument, precondition: precondition, target: target, body)
    )
  }

  /// Adds a rule that draws an argument and mutates the state when enabled.
  public mutating func rule<Argument: Sendable>(
    _ name: String,
    argument: Strategy<Argument>,
    precondition: @escaping @Sendable (State) async throws -> Bool = { _ in true },
    _ body: @escaping @Sendable (inout State, Argument) async throws -> Void
  ) {
    rules.append(makeRule(name: name, argument: argument, precondition: precondition, body))
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
      makeRule(name: name, argument: argument, precondition: precondition, target: target, body)
    )
  }

  /// Adds a rule that saves multiple outputs into bundles.
  public mutating func rule<Argument: Sendable, First: Sendable, Second: Sendable>(
    _ name: String,
    argument: Strategy<Argument>,
    precondition: @escaping @Sendable (State) async throws -> Bool = { _ in true },
    targets: (StateMachineBundle<First>, StateMachineBundle<Second>),
    _ body: @escaping @Sendable (inout State, Argument) async throws -> (First, Second)
  ) {
    rules.append(
      makeRule(name: name, argument: argument, precondition: precondition, targets: targets, body)
    )
  }

  /// Adds an invariant checked before initialization and after every executed rule.
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

/// Runs the given machine for several generated examples.
public func checkRuleBasedStateMachine<State: Sendable>(
  _ machine: RuleBasedStateMachine<State>,
  config: StateMachineConfig = StateMachineConfig()
) async throws {
  let baseSeed = config.seed ?? UInt64.random(in: .min ... .max)
  let database = config.localDatabaseDirectory.map { FileBackedDatabase(rootDirectory: $0) }
  let persistedTraces: [ChoiceTrace]
  if config.replayEnabled, let database {
    persistedTraces = try await database.loadTraces(for: config.propertyID)
  } else {
    persistedTraces = []
  }

  let replayTraces = config.replayEnabled ? config.replayTraces + persistedTraces : []
  for (index, trace) in replayTraces.enumerated() {
    let metadata = StateMachineRunMetadata(baseSeed: baseSeed, exampleIndex: -1 - index)
    do {
      try await runOnce(machine, config: config, provider: ReplayProvider(trace: trace), metadata: metadata)
    } catch let failure as StateMachineFailure {
      try await persist(failure: failure, config: config, database: database)
      throw failure
    }
  }

  for exampleIndex in 0..<config.maxExamples {
    let seed = baseSeed &+ UInt64(exampleIndex)
    let metadata = StateMachineRunMetadata(
      baseSeed: baseSeed,
      exampleIndex: exampleIndex
    )
    do {
      try await runOnce(
        machine,
        config: config,
        provider: PseudoRandomProvider(seed: seed, maxDraws: config.maxDrawsPerExample),
        metadata: metadata
      )
    } catch let failure as StateMachineFailure {
      let minimized = await shrinkFailure(
        failure,
        machine: machine,
        config: config,
        metadata: metadata
      )
      try await persist(failure: minimized, config: config, database: database)
      throw minimized
    }
  }
}

private func runOnce<State: Sendable, Provider: PrimitiveProvider>(
  _ machine: RuleBasedStateMachine<State>,
  config: StateMachineConfig,
  provider: Provider,
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

  let context = StateMachineRunContext()
  var data = PremiseData(provider: provider)
  var program = StateMachineProgram()

  do {
    try await checkInvariants(
      machine.invariants,
      state: state,
      metadata: metadata,
      step: -1,
      duringInit: true
    )

    try await executeInitializers(
      machine.initializers,
      invariants: machine.invariants,
      state: &state,
      context: context,
      data: &data,
      program: &program,
      metadata: metadata
    )

    try await checkInvariants(
      machine.invariants,
      state: state,
      metadata: metadata,
      step: -1,
      duringInit: false
    )

    for step in 0..<config.maxSteps {
      let executed = try await executeStep(
        rules: machine.rules,
        state: &state,
        context: context,
        data: &data,
        program: &program,
        metadata: metadata,
        step: step
      )
      guard executed else { break }
      try await checkInvariants(
        machine.invariants,
        state: state,
        metadata: metadata,
        step: step,
        duringInit: false
      )
    }

    try await executeTeardowns(machine.teardowns, state: &state, metadata: metadata)
  } catch let failure as StateMachineFailure {
    if failure.phase != .teardown {
      try? await executeTeardowns(machine.teardowns, state: &state, metadata: metadata)
    }
    throw failure.with(
      replayTrace: data.snapshot(),
      program: program,
      shrinkCount: failure.shrinkCount
    )
  } catch {
    try? await executeTeardowns(machine.teardowns, state: &state, metadata: metadata)
    throw stateMachineFailure(
      wrapping: error,
      metadata: metadata,
      step: program.steps.last?.index ?? -1,
      phase: .rule
    )
    .with(replayTrace: data.snapshot(), program: program, shrinkCount: 0)
  }
}

private func executeInitializers<State: Sendable>(
  _ initializers: [StateMachineRule<State>],
  invariants: [StateMachineInvariant<State>],
  state: inout State,
  context: StateMachineRunContext,
  data: inout PremiseData,
  program: inout StateMachineProgram,
  metadata: StateMachineRunMetadata
) async throws {
  for (index, initializer) in initializers.enumerated() {
    do {
      guard try await initializer.isEnabled(state) else { continue }
      guard let execution = try await initializer.run(&state, context, &data) else {
        continue
      }
      let initializerStep = -initializers.count + index
      program.steps.append(
        StateMachineProgramStep(
          index: initializerStep,
          ruleName: execution.ruleName,
          argumentDescription: execution.argumentDescription,
          outputs: execution.outputs
        )
      )
      try await checkInvariants(
        invariants,
        state: state,
        metadata: metadata,
        step: initializerStep,
        duringInit: true
      )
    } catch {
      throw stateMachineFailure(
        wrapping: error,
        metadata: metadata,
        step: -1,
        phase: .initialize,
        ruleName: initializer.name
      )
    }
  }
}

private func executeStep<State: Sendable>(
  rules: [StateMachineRule<State>],
  state: inout State,
  context: StateMachineRunContext,
  data: inout PremiseData,
  program: inout StateMachineProgram,
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
      if let execution = try await rule.run(&state, context, &data) {
        program.steps.append(
          StateMachineProgramStep(
            index: step,
            ruleName: execution.ruleName,
            argumentDescription: execution.argumentDescription,
            outputs: execution.outputs
          )
        )
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
  step: Int,
  duringInit: Bool
) async throws {
  for invariant in invariants where !duringInit || invariant.checkDuringInit {
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

private func executeTeardowns<State: Sendable>(
  _ teardowns: [StateMachineTeardown<State>],
  state: inout State,
  metadata: StateMachineRunMetadata
) async throws {
  for teardown in teardowns {
    do {
      try await teardown.body(&state)
    } catch {
      throw stateMachineFailure(
        wrapping: error,
        metadata: metadata,
        step: -1,
        phase: .teardown,
        ruleName: teardown.name
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

private func makeRule<State: Sendable, Argument: Sendable>(
  name: String,
  argument: Strategy<Argument>,
  precondition: @escaping @Sendable (State) async throws -> Bool,
  _ body: @escaping @Sendable (inout State, Argument) async throws -> Void
) -> StateMachineRule<State> {
  StateMachineRule(
    name: name,
    isEnabled: precondition,
    run: { state, context, data in
      guard
        let drawnArgument = try data.withSpan(name, { spanData in
          try draw(argument, using: &spanData, context: context)
        })
      else {
        return nil
      }

      try await body(&state, drawnArgument)
      return StateMachineStepExecution(
        ruleName: name,
        argumentDescription: String(describing: drawnArgument)
      )
    }
  )
}

private func makeRule<State: Sendable, Argument: Sendable, Element: Sendable>(
  name: String,
  argument: Strategy<Argument>,
  precondition: @escaping @Sendable (State) async throws -> Bool,
  target: StateMachineBundle<Element>,
  _ body: @escaping @Sendable (inout State, Argument) async throws -> Element
) -> StateMachineRule<State> {
  StateMachineRule(
    name: name,
    isEnabled: precondition,
    run: { state, context, data in
      guard
        let drawnArgument = try data.withSpan(name, { spanData in
          try draw(argument, using: &spanData, context: context)
        })
      else {
        return nil
      }

      let element = try await body(&state, drawnArgument)
      context.append(element, to: target)
      return StateMachineStepExecution(
        ruleName: name,
        argumentDescription: String(describing: drawnArgument),
        outputs: ["\(target.label)=\(String(describing: element))"]
      )
    }
  )
}

private func makeRule<State: Sendable, Argument: Sendable, First: Sendable, Second: Sendable>(
  name: String,
  argument: Strategy<Argument>,
  precondition: @escaping @Sendable (State) async throws -> Bool,
  targets: (StateMachineBundle<First>, StateMachineBundle<Second>),
  _ body: @escaping @Sendable (inout State, Argument) async throws -> (First, Second)
) -> StateMachineRule<State> {
  StateMachineRule(
    name: name,
    isEnabled: precondition,
    run: { state, context, data in
      guard
        let drawnArgument = try data.withSpan(name, { spanData in
          try draw(argument, using: &spanData, context: context)
        })
      else {
        return nil
      }

      let output = try await body(&state, drawnArgument)
      context.append(output.0, to: targets.0)
      context.append(output.1, to: targets.1)
      return StateMachineStepExecution(
        ruleName: name,
        argumentDescription: String(describing: drawnArgument),
        outputs: [
          "\(targets.0.label)=\(String(describing: output.0))",
          "\(targets.1.label)=\(String(describing: output.1))",
        ]
      )
    }
  )
}

private func shrinkFailure<State: Sendable>(
  _ failure: StateMachineFailure,
  machine: RuleBasedStateMachine<State>,
  config: StateMachineConfig,
  metadata: StateMachineRunMetadata
) async -> StateMachineFailure {
  var best = failure
  var iterations = 0

  func tryTrace(_ candidate: ChoiceTrace) async -> Bool {
    do {
      try await runOnce(machine, config: config, provider: ReplayProvider(trace: candidate), metadata: metadata)
      return false
    } catch let candidateFailure as StateMachineFailure {
      guard candidateFailure.matches(failure) else {
        return false
      }
      best = candidateFailure.with(
        replayTrace: candidate,
        program: candidateFailure.program,
        shrinkCount: iterations + 1
      )
      iterations += 1
      return true
    } catch {
      return false
    }
  }

  while iterations < config.maxShrinkIterations {
    var improved = false
    for span in best.replayTrace.spans.reversed() {
      if await tryTrace(removing(span: span, from: best.replayTrace)) {
        improved = true
        break
      }
    }
    if improved { continue }

    for index in best.replayTrace.entries.indices {
      guard case .integer(let value) = best.replayTrace.entries[index], value > 0 else {
        continue
      }
      for candidateValue in [UInt64(0), value / 2, value - 1] {
        var candidate = best.replayTrace
        candidate.entries[index] = .integer(candidateValue)
        if await tryTrace(candidate) {
          improved = true
          break
        }
      }
      if improved { break }
    }

    if !improved { break }
  }

  return best.with(
    replayTrace: best.replayTrace,
    program: best.program,
    shrinkCount: iterations
  )
}

private extension StateMachineFailure {
  func matches(_ original: StateMachineFailure) -> Bool {
    phase == original.phase
      && ruleName == original.ruleName
      && invariantName == original.invariantName
      && underlyingDescription == original.underlyingDescription
  }
}

private func removing(span: ChoiceTrace.Span, from trace: ChoiceTrace) -> ChoiceTrace {
  var candidate = trace
  guard span.start < span.end, span.end <= candidate.entries.count else {
    return candidate
  }
  candidate.entries.removeSubrange(span.start..<span.end)
  candidate.spans = candidate.spans.compactMap { existing in
    adjust(span: existing, removed: span)
  }
  return candidate
}

private func adjust(
  span: ChoiceTrace.Span,
  removed: ChoiceTrace.Span
) -> ChoiceTrace.Span? {
  if span.end <= removed.start {
    return span
  }
  if span.start >= removed.end {
    return ChoiceTrace.Span(
      label: span.label,
      start: span.start - (removed.end - removed.start),
      end: span.end - (removed.end - removed.start)
    )
  }
  return nil
}

private func persist(
  failure: StateMachineFailure,
  config: StateMachineConfig,
  database: FileBackedDatabase?
) async throws {
  let record = FailureRecord(
    propertyID: config.propertyID,
    trace: failure.replayTrace,
    errorMessage: failure.description,
    runCount: max(0, failure.exampleIndex + 1),
    shrinkCount: failure.shrinkCount,
    seed: failure.baseSeed,
    statistics: RunStatistics(notes: [RunNote(label: "program", value: failure.program.description)], events: [], targetScore: nil)
  )
  if let database {
    try await database.save(record)
  }
  guard let directory = config.traceExportDirectory else { return }
  _ = try FailureTraceExporter.export(
    FailureTraceArtifact(record: record, valueDescription: failure.program.description),
    to: directory
  )
}

private struct StateMachineRule<State: Sendable>: Sendable {
  var name: String
  var isEnabled: @Sendable (State) async throws -> Bool
  var run:
    @Sendable (
      inout State,
      StateMachineRunContext,
      inout PremiseData
    ) async throws -> StateMachineStepExecution?
}

private struct StateMachineStepExecution: Sendable {
  var ruleName: String
  var argumentDescription: String
  var outputs: [String] = []
}

private struct StateMachineInvariant<State: Sendable>: Sendable {
  var name: String
  var checkDuringInit: Bool
  var check: @Sendable (State) async throws -> Void
}

private struct StateMachineTeardown<State: Sendable>: Sendable {
  var name: String
  var body: @Sendable (inout State) async throws -> Void
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

private final class StateMachineRunContext: @unchecked Sendable {
  private var storage: [StateMachineBundleKey: [any Sendable]] = [:]

  func values<Element: Sendable>(for key: StateMachineBundleKey) -> [Element] {
    guard let values = storage[key] else { return [] }
    return values.compactMap { $0 as? Element }
  }

  func append<Element: Sendable>(
    _ element: Element,
    to bundle: StateMachineBundle<Element>
  ) {
    storage[bundle.key, default: []].append(element)
  }

  func removeValue<Element: Sendable>(
    at index: Int,
    for key: StateMachineBundleKey
  ) -> Element? {
    guard var values = storage[key], values.indices.contains(index) else {
      return nil
    }
    let removed = values.remove(at: index)
    storage[key] = values
    return removed as? Element
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
