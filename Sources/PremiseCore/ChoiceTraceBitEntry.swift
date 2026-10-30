extension ChoiceTrace {
  /// A recorded bit draw.
  public struct BitEntry: Sendable, Codable, Equatable {
    /// The number of requested bits.
    public var count: Int
    /// The recorded value.
    public var value: UInt64

    /// Creates a bit draw.
    public init(count: Int, value: UInt64) {
      self.count = count
      self.value = value
    }
  }
}
