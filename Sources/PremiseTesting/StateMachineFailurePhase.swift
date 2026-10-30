extension StateMachineFailure {
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
    /// An invariant failed before a run, during initialization, or after a
    /// rule step.
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
}
