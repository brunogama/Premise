/// Failure metadata recorded in a JSON Lines run event.
public struct RunJSONLFailure: Sendable, Codable, Equatable {
  /// Error message captured from the failing property.
  public var errorMessage: String

  /// Number of entries in the minimized replay trace.
  public var traceEntryCount: Int

  /// Number of successful shrink steps applied to the failure.
  public var shrinkCount: Int

  /// Base seed that discovered the failure, when available.
  public var seed: UInt64?

  /// Whether the failure was newly found or replayed from a corpus.
  public var discovery: FailureDiscovery

  /// Copy-paste replay blob for tooling and diagnostics.
  public var reproductionBlob: String?

  /// Creates failure metadata from a recorded failure.
  public init(record: FailureRecord) {
    self.errorMessage = record.errorMessage
    self.traceEntryCount = record.trace.entries.count
    self.shrinkCount = record.shrinkCount
    self.seed = record.seed
    self.discovery = record.discovery
    self.reproductionBlob = try? record.trace.reproductionBlob()
  }
}
