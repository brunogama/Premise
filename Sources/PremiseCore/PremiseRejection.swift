/// Error used to reject the current example without failing the property.
public enum PremiseRejection: Error, Sendable, Equatable,
  CustomStringConvertible
{
  /// The property assumed a condition that was not satisfied.
  case assumptionFailed(reason: String? = nil)

  /// A description of the rejection.
  public var description: String {
    switch self {
    case .assumptionFailed(let reason):
      if let reason, !reason.isEmpty {
        return "Assumption rejected: \(reason)"
      }
      return "Assumption rejected"
    }
  }
}
