/// Pass/fail outcome recorded in a JSON Lines run event.
public enum RunJSONLOutcome: String, Sendable, Codable, Equatable {
  case passed
  case failed
}
