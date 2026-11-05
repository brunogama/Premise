/// Runtime health checks that can produce non-fatal warnings.
public enum HealthCheck: String, Sendable, Codable, Hashable, CaseIterable {
  case excessiveFiltering
  case slowGeneration
  case emptySearch
}
