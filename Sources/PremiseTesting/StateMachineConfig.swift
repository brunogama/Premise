import Foundation
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
    precondition(
      maxDrawsPerExample >= 0,
      "maxDrawsPerExample must be non-negative"
    )
    precondition(
      maxShrinkIterations >= 0,
      "maxShrinkIterations must be non-negative"
    )
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
