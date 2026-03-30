/// Witness-backed generation contract for future property strategies.
public struct Strategy<Value: Sendable>: Sendable {
  public let label: String
  public let draw: @Sendable (inout ConjectureData) throws -> Value
  public let shrink: @Sendable (Value) -> [Value]

  public init(
    label: String,
    draw: @escaping @Sendable (inout ConjectureData) throws -> Value,
    shrink: @escaping @Sendable (Value) -> [Value] = { _ in [] }
  ) {
    self.label = label
    self.draw = draw
    self.shrink = shrink
  }
}
