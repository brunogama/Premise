/// Version policy for Z3 runtime compatibility.
///
/// Declares the minimum supported Z3 version and provides
/// runtime version checking when the SMT trait is enabled.
public struct Z3VersionPolicy: Sendable, Equatable {
    /// The minimum Z3 major version supported by ConjectureSMT.
    public static let minimumMajor: UInt32 = 4

    /// The minimum Z3 minor version supported by ConjectureSMT.
    public static let minimumMinor: UInt32 = 12

    /// The minimum Z3 patch version supported by ConjectureSMT.
    public static let minimumPatch: UInt32 = 0

    /// The detected Z3 runtime version, if available.
    public let major: UInt32
    public let minor: UInt32
    public let patch: UInt32

    /// Creates a version policy with the given version components.
    public init(major: UInt32, minor: UInt32, patch: UInt32) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Whether this version meets the minimum supported baseline.
    public var meetsMinimum: Bool {
        if major > Self.minimumMajor { return true }
        if major < Self.minimumMajor { return false }
        if minor > Self.minimumMinor { return true }
        if minor < Self.minimumMinor { return false }
        return patch >= Self.minimumPatch
    }

    /// A human-readable version string.
    public var versionString: String {
        "\(major).\(minor).\(patch)"
    }

    #if CONJECTURE_SMT
    /// Queries the Z3 runtime for its version.
    ///
    /// Returns `nil` if the Z3 library is not linked or
    /// version query fails.
    public static func detectRuntime() -> Self? {
        var major: UInt32 = 0
        var minor: UInt32 = 0
        var build: UInt32 = 0
        var revision: UInt32 = 0
        CZ3.Z3_get_version(&major, &minor, &build, &revision)
        return Self(major: major, minor: minor, patch: build)
    }
    #endif
}
