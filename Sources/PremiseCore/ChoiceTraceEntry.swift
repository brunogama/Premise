extension ChoiceTrace {
  /// A recorded primitive choice.
  public enum Entry: Sendable, Codable, Equatable {
    case bits(BitEntry)
    case integer(UInt64)
    case boolean(Bool)
    case bytes([UInt8])
  }
}
