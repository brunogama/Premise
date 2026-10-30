/// Outcome of running one external fuzzer input through Premise.
public enum FuzzOutcome: String, Sendable, Codable, Equatable {
  /// The input produced a value and the property did not throw.
  case passed
  /// The strategy or property rejected the input as invalid.
  case rejected
  /// The byte input ran out before Premise could confidently run the property.
  case exhausted
}
