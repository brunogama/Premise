/// Namespace marker for the ConjectureSMT module.
///
/// ConjectureSMT provides optional SMT solver-backed providers
/// for constrained value generation. The module is trait-gated
/// behind the `SMT` SwiftPM trait and requires Z3 to be installed.
public enum ConjectureSMTModule {
    /// The module name.
    public static let name = "ConjectureSMT"
}
