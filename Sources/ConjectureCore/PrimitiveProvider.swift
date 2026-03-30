/// Low-level provider contract for deterministic primitive draws.
public protocol PrimitiveProvider: Sendable {
  mutating func drawBits(count: Int) -> UInt64
  mutating func drawBytes(count: Int) -> [UInt8]
  mutating func markExhausted()
  var isExhausted: Bool { get }
}

public extension PrimitiveProvider {
  mutating func drawBytes(count: Int) -> [UInt8] {
    guard count >= 0 else {
      markExhausted()
      return []
    }

    guard count > 0 else { return [] }
    return (0..<count).map { _ in UInt8(truncatingIfNeeded: drawBits(count: 8)) }
  }
}
