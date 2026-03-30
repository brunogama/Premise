/// Errors raised when a persisted artifact uses an unsupported format version.
///
/// The decode path validates version fields before constructing runtime types.
/// Callers can match on `found` and `supported` to produce actionable
/// diagnostics without exposing internal migration details.
public enum PersistenceCompatibilityError: Error, Equatable, Sendable {
    /// The persisted record envelope version is outside the supported range.
    case unsupportedRecordVersion(found: Int, supported: ClosedRange<Int>)

    /// The persisted trace format version is outside the supported range.
    case unsupportedTraceVersion(found: Int, supported: ClosedRange<Int>)
}

/// Version ranges currently accepted by the persistence layer.
public enum PersistenceVersionPolicy {
    /// Supported record envelope versions.
    public static let supportedRecordVersions: ClosedRange<Int> = 1...1

    /// Supported trace format versions.
    public static let supportedTraceVersions: ClosedRange<Int> = 1...1
}
