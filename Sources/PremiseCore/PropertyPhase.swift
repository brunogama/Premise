/// Logical execution phases for a property run.
public enum PropertyPhase: String, Sendable, Codable, Hashable, CaseIterable {
  /// Run caller-provided examples before generated exploration.
  case explicit

  /// Replay persisted failures from a local database or committed corpus.
  case replay

  /// Generate fresh pseudo-random examples.
  case generate

  /// Minimize a failing example.
  case shrink
}

public extension Array where Element == PropertyPhase {
  /// Default Premise phase order.
  static let premiseDefault: [PropertyPhase] = [
    .explicit,
    .replay,
    .generate,
    .shrink,
  ]

  /// Returns true when the phase is enabled.
  func includes(_ phase: PropertyPhase) -> Bool {
    contains(phase)
  }
}
