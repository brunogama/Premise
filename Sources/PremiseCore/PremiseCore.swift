import Foundation

public enum PremiseCoreModule {
  public static let name = "PremiseCore"
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

  public init(
    propertyID: PropertyIdentity,
    trace: ChoiceTrace,
    errorMessage: String,
    runCount: Int = 0,
    shrinkCount: Int = 0,
    timestamp: Date = Date(),
    engineVersion: String = "0.2.0",
    seed: UInt64? = nil
  ) {
    self.propertyID = propertyID
    self.trace = trace
    self.errorMessage = errorMessage
    self.runCount = runCount
    self.shrinkCount = shrinkCount
    self.timestamp = timestamp
    self.engineVersion = engineVersion
    self.seed = seed
  }
}
