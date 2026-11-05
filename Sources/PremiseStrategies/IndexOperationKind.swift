public extension IndexOperation {
  /// Kind of index operation.
  enum Kind: String, Sendable, Codable {
    case insert
    case update
    case delete
    case query
  }
}
