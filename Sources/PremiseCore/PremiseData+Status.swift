extension PremiseData {
  /// Execution status for the current draw.
  public enum Status: Sendable, Codable, Equatable {
    /// The draw can continue.
    case active

    /// The primitive provider has no more replay data or draw budget.
    case exhausted

    /// The current example was marked interesting by the property.
    case interesting
  }
}
