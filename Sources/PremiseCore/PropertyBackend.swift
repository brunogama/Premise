/// Primitive generation backend selected for a property run.
public enum PropertyBackend: String, Sendable, Codable, Hashable, CaseIterable {
  /// The default deterministic Premise provider.
  case premise

  /// Solver-backed generation when the SMT extension is available.
  case smt

  /// Coverage-guided generation when instrumentation is available.
  case coverageGuided
}
