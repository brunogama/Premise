/// Z3 availability gate for the ConjectureSMT module.
///
/// When the `SMT` trait is enabled and Z3 headers are present,
/// `CONJECTURE_SMT` is defined via Package.swift build settings.
/// All Z3-dependent code should be gated behind `#if CONJECTURE_SMT`.
public enum Z3Availability: Sendable {
    /// Whether the SMT trait was enabled at compile time.
    public static var isCompileTimeEnabled: Bool {
        #if CONJECTURE_SMT
        return true
        #else
        return false
        #endif
    }
}
