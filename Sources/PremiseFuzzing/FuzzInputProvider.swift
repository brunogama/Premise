import Foundation
import PremiseCore

/// Primitive provider backed by bytes supplied by an external fuzzer.
///
/// `FuzzInputProvider` consumes bytes in order and pads incomplete primitive
/// draws with zeroes while marking the input as exhausted. This lets strategies
/// use the same ``PremiseData`` draw APIs under libFuzzer, AFL, or other
/// byte-oriented fuzzing engines without adding fuzzer-specific concepts to
/// `PremiseCore`.
public struct FuzzInputProvider: PrimitiveProvider {
  private let bytes: [UInt8]
  private var offset: Int
  private var exhausted: Bool

  /// Creates a provider from raw bytes.
  public init(bytes: [UInt8]) {
    self.bytes = bytes
    offset = 0
    exhausted = false
  }

  /// Creates a provider from Foundation data.
  public init(_ data: Data) {
    self.init(bytes: Array(data))
  }

  /// Number of bytes supplied by the fuzzer.
  public var byteCount: Int { bytes.count }

  /// Number of whole bytes consumed so far.
  public var consumedByteCount: Int { offset }

  /// Number of whole bytes remaining.
  public var remainingByteCount: Int { max(0, bytes.count - offset) }

  /// Draws bits from the remaining input bytes.
  public mutating func drawBits(count: Int) -> UInt64 {
    guard count >= 0 else {
      markExhausted()
      return 0
    }

    guard count > 0 else { return 0 }

    let byteCount = min(8, (count + 7) / 8)
    let drawn = drawBytes(count: byteCount)
    var value: UInt64 = 0
    for (index, byte) in drawn.enumerated() {
      value |= UInt64(byte) << UInt64(index * 8)
    }

    guard count < 64 else { return value }
    return value & ((1 << count) - 1)
  }

  /// Draws bytes, padding with zeroes when the input runs out.
  public mutating func drawBytes(count: Int) -> [UInt8] {
    guard count >= 0 else {
      markExhausted()
      return []
    }

    guard count > 0 else { return [] }
    guard offset < bytes.count else {
      markExhausted()
      return Array(repeating: 0, count: count)
    }

    let end = min(bytes.count, offset + count)
    let drawn = Array(bytes[offset..<end])
    offset = end

    guard drawn.count == count else {
      markExhausted()
      return drawn + Array(repeating: 0, count: count - drawn.count)
    }

    return drawn
  }

  /// Marks the input as exhausted.
  public mutating func markExhausted() {
    exhausted = true
  }

  /// Whether a draw exhausted the input.
  public var isExhausted: Bool {
    exhausted
  }
}
