/// A non-fatal warning about property execution quality.
public struct HealthWarning: Sendable, Codable, Equatable {
  /// Health check that produced the warning.
  public let check: HealthCheck

  /// Human-readable warning message.
  public let message: String

  /// Creates a health warning.
  public init(check: HealthCheck, message: String) {
    self.check = check
    self.message = message
  }
}
