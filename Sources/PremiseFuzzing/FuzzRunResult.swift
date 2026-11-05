import PremiseCore

/// Result returned by ``fuzzOneInput(_:strategy:config:_:)`` when no failure is found.
public struct FuzzRunResult: Sendable, Codable, Equatable {
  /// Classification of the fuzzer input.
  public let outcome: FuzzOutcome
  /// Number of bytes supplied by the fuzzer.
  public let inputByteCount: Int
  /// Choice trace observed while interpreting the bytes.
  public let trace: ChoiceTrace
  /// Optional rejection reason for invalid inputs.
  public let rejectionReason: String?

  /// Creates a result for one fuzz input.
  public init(
    outcome: FuzzOutcome,
    inputByteCount: Int,
    trace: ChoiceTrace,
    rejectionReason: String? = nil
  ) {
    self.outcome = outcome
    self.inputByteCount = inputByteCount
    self.trace = trace
    self.rejectionReason = rejectionReason
  }
}
