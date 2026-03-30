/// Namespace marker for the PremiseSMT module.
///
/// PremiseSMT provides optional SMT solver-backed providers
/// for constrained value generation. The module is trait-gated
/// behind the `SMT` SwiftPM trait and requires Z3 to be installed.
public enum PremiseSMTModule {
  /// The module name.
  public static let name = "PremiseSMT"
}
