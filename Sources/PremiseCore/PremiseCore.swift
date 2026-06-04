import Foundation

public enum PremiseCoreModule {
  public static let name = "PremiseCore"
}

/// Indicates whether a failure was discovered during fresh generation or
/// reproduced from a persisted replay trace.
public enum FailureDiscovery: String, Sendable, Codable, Equatable {
  case newFailure
  case knownFailure
}

/// Minimal persisted failure envelope shared between the core and storage.
public struct FailureRecord: Sendable, Codable, Equatable {
  public var propertyID: PropertyIdentity
  public var trace: ChoiceTrace
  public var errorMessage: String
  public var runCount: Int
  public var shrinkCount: Int
  public var timestamp: Date
  public var engineVersion: String

  /// The base seed used during the run that discovered this failure.
  ///
  /// When non-nil the exact failing run can be reproduced by passing
  /// `PropertyConfig(seed: record.seed)` to the runner.
  public var seed: UInt64?

  /// Classification used by adapters and CI output to distinguish newly
  /// discovered failures from replayed corpus failures.
  public var discovery: FailureDiscovery

  public init(
    propertyID: PropertyIdentity,
    trace: ChoiceTrace,
    errorMessage: String,
    runCount: Int = 0,
    shrinkCount: Int = 0,
    timestamp: Date = Date(),
    engineVersion: String = "1.0.0",
    seed: UInt64? = nil,
    discovery: FailureDiscovery = .newFailure
  ) {
    self.propertyID = propertyID
    self.trace = trace
    self.errorMessage = errorMessage
    self.runCount = runCount
    self.shrinkCount = shrinkCount
    self.timestamp = timestamp
    self.engineVersion = engineVersion
    self.seed = seed
    self.discovery = discovery
  }
}

/// JSON-exportable replay artifact for CI and local debugging.
public struct FailureTraceArtifact: Sendable, Codable, Equatable {
  public var record: FailureRecord
  public var valueDescription: String?

  public init(
    record: FailureRecord,
    valueDescription: String? = nil
  ) {
    self.record = record
    self.valueDescription = valueDescription
  }

  public var trace: ChoiceTrace {
    record.trace
  }
}
