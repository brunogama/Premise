/// Summary of one distinct failure observed during a run.
public struct RunFailureSummary: Sendable, Codable, Equatable {
  /// Phase that observed the failure.
  public let phase: PropertyPhase

  /// Error message captured from the failing property.
  public let errorMessage: String

  /// Number of entries in the minimized trace.
  public let traceEntryCount: Int

  /// Number of shrink steps applied to this failure.
  public let shrinkCount: Int

  /// Whether the failure was newly found or replayed from corpus.
  public let discovery: FailureDiscovery

  /// Creates a compact failure summary.
  public init(phase: PropertyPhase, record: FailureRecord) {
    self.phase = phase
    self.errorMessage = record.errorMessage
    self.traceEntryCount = record.trace.entries.count
    self.shrinkCount = record.shrinkCount
    self.discovery = record.discovery
  }
}
