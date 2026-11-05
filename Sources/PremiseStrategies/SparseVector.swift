/// Sparse vector value used by built-in vector-ish strategies.
public struct SparseVector: Sendable, Equatable, Codable {
  /// Number of vector dimensions.
  public var dimensions: Int
  /// Values indexed by dimension.
  public var entries: [Int: Double]

  /// Creates a sparse vector from its dimensions and entries.
  public init(dimensions: Int, entries: [Int: Double]) {
    self.dimensions = dimensions
    self.entries = entries
  }
}
