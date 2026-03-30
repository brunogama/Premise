import ConjectureCore

/// A primitive provider that uses an SMT solver to generate
/// constrained values when the SMT trait is enabled, falling
/// back to standard pseudo-random generation otherwise.
///
/// When `CONJECTURE_SMT` is not defined, the provider delegates
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

    public mutating func drawBits(count: Int) -> UInt64 {
        fallback.drawBits(count: count)
    }

    public mutating func drawBytes(count: Int) -> [UInt8] {
        fallback.drawBytes(count: count)
    }

    public mutating func markExhausted() {
        exhaustedFlag = true
        fallback.markExhausted()
    }

    public var isExhausted: Bool {
        exhaustedFlag || fallback.isExhausted
    }
}
