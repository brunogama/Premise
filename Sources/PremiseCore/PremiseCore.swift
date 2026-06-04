import Foundation

/// Namespace marker for the PremiseCore product.
public enum PremiseCoreModule {
  /// The package product name.
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
  /// Stable identity for the property that produced the failure.
  public var propertyID: PropertyIdentity

  /// Canonical choice trace that replays the minimized failure.
  public var trace: ChoiceTrace

  /// Human-readable failure reason captured from the thrown error.
  public var errorMessage: String

  /// Number of generated examples attempted before the failure.
  public var runCount: Int

  /// Number of successful shrink steps applied to the failure.
  public var shrinkCount: Int

  /// Time at which the failure record was created.
  public var timestamp: Date

  /// Premise engine version that wrote the record.
  public var engineVersion: String

  /// The base seed used during the run that discovered this failure.
  ///
  /// When non-nil the exact failing run can be reproduced by passing
  /// `PropertyConfig(seed: record.seed)` to the runner.
  public var seed: UInt64?

  /// Classification used by adapters and CI output to distinguish newly
  /// discovered failures from replayed corpus failures.
  public var discovery: FailureDiscovery

  /// Observations from the run that produced the minimized failure.
  public var statistics: RunStatistics

  /// Creates a persisted failure record.
  public init(
    propertyID: PropertyIdentity,
    trace: ChoiceTrace,
    errorMessage: String,
    runCount: Int = 0,
    shrinkCount: Int = 0,
    timestamp: Date = Date(),
    engineVersion: String = "1.0.0",
    seed: UInt64? = nil,
    discovery: FailureDiscovery = .newFailure,
    statistics: RunStatistics = RunStatistics()
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
    self.statistics = statistics
  }

  private enum CodingKeys: String, CodingKey {
    case propertyID
    case trace
    case errorMessage
    case runCount
    case shrinkCount
    case timestamp
    case engineVersion
    case seed
    case discovery
    case statistics
  }

  /// Decodes a failure record, applying defaults for fields added after
  /// the initial persistence format.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    propertyID = try container.decode(PropertyIdentity.self, forKey: .propertyID)
    trace = try container.decode(ChoiceTrace.self, forKey: .trace)
    errorMessage = try container.decode(String.self, forKey: .errorMessage)
    runCount = try container.decode(Int.self, forKey: .runCount)
    shrinkCount = try container.decode(Int.self, forKey: .shrinkCount)
    timestamp = try container.decode(Date.self, forKey: .timestamp)
    engineVersion = try container.decode(String.self, forKey: .engineVersion)
    seed = try container.decodeIfPresent(UInt64.self, forKey: .seed)
    discovery =
      try container.decodeIfPresent(FailureDiscovery.self, forKey: .discovery)
      ?? .newFailure
    statistics =
      try container.decodeIfPresent(RunStatistics.self, forKey: .statistics)
      ?? RunStatistics()
  }

  /// Encodes the failure record in the current persistence format.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(propertyID, forKey: .propertyID)
    try container.encode(trace, forKey: .trace)
    try container.encode(errorMessage, forKey: .errorMessage)
    try container.encode(runCount, forKey: .runCount)
    try container.encode(shrinkCount, forKey: .shrinkCount)
    try container.encode(timestamp, forKey: .timestamp)
    try container.encode(engineVersion, forKey: .engineVersion)
    try container.encodeIfPresent(seed, forKey: .seed)
    try container.encode(discovery, forKey: .discovery)
    try container.encode(statistics, forKey: .statistics)
  }
}

/// JSON-exportable replay artifact for CI and local debugging.
public struct FailureTraceArtifact: Sendable, Codable, Equatable {
  /// Failure metadata and canonical replay trace.
  public var record: FailureRecord

  /// Optional pretty-printed minimized value for diagnostics.
  public var valueDescription: String?

  /// Creates an exportable failure trace artifact.
  public init(
    record: FailureRecord,
    valueDescription: String? = nil
  ) {
    self.record = record
    self.valueDescription = valueDescription
  }

  /// Canonical replay trace for the exported failure.
  public var trace: ChoiceTrace {
    record.trace
  }
}
