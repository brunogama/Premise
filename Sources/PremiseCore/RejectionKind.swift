/// Distinguishes where an example was rejected.
public enum RejectionKind: String, Sendable, Codable, Hashable, CaseIterable {
  /// The strategy could not draw a satisfying value.
  case draw

  /// The property body rejected the example after observing generated data.
  case property
}
