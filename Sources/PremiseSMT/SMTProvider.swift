import PremiseCore

/// A primitive provider that uses an SMT solver to generate
/// constrained values when the SMT trait is enabled, falling
/// back to standard pseudo-random generation otherwise.
///
/// When `PREMISE_SMT` is not defined, the provider delegates
/// entirely to a `PseudoRandomProvider` and the solver path is
/// compiled out.
public struct SMTProvider: PrimitiveProvider, Sendable {
  private var fallback: PseudoRandomProvider
  private var exhaustedFlag: Bool

  /// Creates an SMT provider with the given seed.
  ///
  /// - Parameter seed: The deterministic seed for fallback generation.
  public init(seed: UInt64) {
    self.fallback = PseudoRandomProvider(seed: seed)
    self.exhaustedFlag = false
  }

  /// Draws the requested number of bits from the fallback provider.
  public mutating func drawBits(count: Int) -> UInt64 {
    fallback.drawBits(count: count)
  }

  /// Draws the requested number of bytes from the fallback provider.
  public mutating func drawBytes(count: Int) -> [UInt8] {
    fallback.drawBytes(count: count)
  }

  /// Marks this provider and its fallback as exhausted.
  public mutating func markExhausted() {
    exhaustedFlag = true
    fallback.markExhausted()
  }

  /// Whether this provider or its fallback is exhausted.
  public var isExhausted: Bool {
    exhaustedFlag || fallback.isExhausted
  }
}
