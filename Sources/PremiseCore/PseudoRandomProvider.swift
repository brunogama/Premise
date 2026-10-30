/// A deterministic primitive provider seeded with a pseudorandom state.
public struct PseudoRandomProvider: PrimitiveProvider {
  private var state: UInt64
  private var remainingDraws: Int
  private var exhausted: Bool

  /// Creates a provider with a seed and an optional draw limit.
  public init(seed: UInt64, maxDraws: Int = .max) {
    state = seed
    remainingDraws = maxDraws
    exhausted = maxDraws < 0
  }

  /// Draws up to 64 pseudorandom bits, respecting the draw limit.
  public mutating func drawBits(count: Int) -> UInt64 {
    guard count >= 0 else {
      markExhausted()
      return 0
    }

    guard count > 0 else { return 0 }
    guard !isExhausted else { return 0 }

    if remainingDraws == 0 {
      markExhausted()
      return 0
    }

    if remainingDraws != .max {
      remainingDraws -= 1
    }

    return next() & mask(for: count)
  }

  /// Draws the requested number of bytes from the provider.
  public mutating func drawBytes(count: Int) -> [UInt8] {
    guard count > 0 else { return [] }
    return (0..<count).map { _ in
      UInt8(truncatingIfNeeded: drawBits(count: 8))
    }
  }

  /// Marks the provider as exhausted.
  public mutating func markExhausted() {
    exhausted = true
  }

  /// Whether the provider has been marked exhausted.
  public var isExhausted: Bool {
    exhausted
  }

  private mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }

  private func mask(for count: Int) -> UInt64 {
    if count >= 64 { return .max }
    return (1 << count) - 1
  }
}
