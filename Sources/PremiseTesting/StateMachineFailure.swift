import PremiseCore

/// Error raised when a rule-based state machine check fails.
public struct StateMachineFailure: Error, Sendable, CustomStringConvertible {
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
    underlyingDescription: String,
    ruleName: String? = nil,
    invariantName: String? = nil,
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

  func with(
    replayTrace: ChoiceTrace,
    program: StateMachineProgram,
    shrinkCount: Int
  ) -> Self {
    Self(
      baseSeed: baseSeed,
      exampleIndex: exampleIndex,
      step: step,
      phase: phase,
      underlyingDescription: underlyingDescription,
      ruleName: ruleName,
      invariantName: invariantName,
      replayTrace: replayTrace,
      program: program,
      shrinkCount: shrinkCount
    )
  }
}
