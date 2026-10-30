/// Generic index workflow operation for model-based index tests.
public struct IndexOperation: Sendable, Equatable, Codable {

  /// Operation kind.
  public var kind: Kind
  /// Index addressed by the operation.
  public var index: Int
  /// Optional operation payload.
  public var value: Int?

  /// Creates an index operation.
  public init(kind: Kind, index: Int, value: Int? = nil) {
    self.kind = kind
    self.index = index
    self.value = value
  }
}
