/// Z3 availability gate for the PremiseSMT module.
///
/// When the `SMT` trait is enabled and Z3 headers are present,
/// `PREMISE_SMT` is defined via Package.swift build settings.
/// All Z3-dependent code should be gated behind `#if PREMISE_SMT`.
public enum Z3Availability: Sendable {
  /// Whether the SMT trait was enabled at compile time.
  public static var isCompileTimeEnabled: Bool {
    #if PREMISE_SMT
    return true
    #else
    return false
    #endif
  }
}
