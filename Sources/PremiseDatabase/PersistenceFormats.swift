import PremiseCore
import Foundation

/// Versioned on-disk envelope for a persisted failure record.
///
/// Persistence DTOs use explicit version fields so the decode path can
/// reject unsupported future formats before constructing runtime types.
public struct PersistedFailureRecordV1: Sendable, Codable, Equatable {
  /// Schema version of the failure-record envelope itself.
  public let recordFormatVersion: Int

  /// Schema version of the trace payload embedded in this record.
  public let traceFormatVersion: Int

  /// Stable identity of the property that produced the failure.
  public let propertyID: PropertyIdentity

  /// Deterministic choice trace that reproduces the failure.
  public let trace: ChoiceTrace

  /// Human-readable description of the error.
  public let errorMessage: String

  /// Number of property runs executed before failure was found.
  public let runCount: Int

  /// Number of shrink attempts applied to reduce the failure.
  public let shrinkCount: Int

  /// Time at which the failure was recorded.
  public let timestamp: Date

  /// Engine version that produced the failure.
  public let engineVersion: String

  /// Creates a versioned persistence envelope.
  ///
  /// - Parameters:
  ///   - recordFormatVersion: Schema version of this envelope (currently 1).
  ///   - traceFormatVersion: Schema version of the embedded trace (currently 1).
  ///   - propertyID: Stable identity of the failing property.
  ///   - trace: Choice trace that reproduces the failure.
  ///   - errorMessage: Human-readable error description.
  ///   - runCount: Runs executed before failure.
  ///   - shrinkCount: Shrink attempts applied.
  ///   - timestamp: When the failure was recorded.
  ///   - engineVersion: Engine version string.
  public init(
    recordFormatVersion: Int = 1,
    traceFormatVersion: Int = 1,
    propertyID: PropertyIdentity,
    trace: ChoiceTrace,
    errorMessage: String,
    runCount: Int,
    shrinkCount: Int,
    timestamp: Date,
    engineVersion: String
  ) {
    self.recordFormatVersion = recordFormatVersion
    self.traceFormatVersion = traceFormatVersion
    self.propertyID = propertyID
    self.trace = trace
    self.errorMessage = errorMessage
    self.runCount = runCount
    self.shrinkCount = shrinkCount
    self.timestamp = timestamp
    self.engineVersion = engineVersion
  }
}
