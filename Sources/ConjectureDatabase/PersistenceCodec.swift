import ConjectureCore
import Foundation

/// Maps between runtime ``FailureRecord`` values and the versioned
/// ``PersistedFailureRecordV1`` envelope used for on-disk storage.
///
/// Every decode path validates format versions before constructing
/// core types, ensuring unsupported future formats fail explicitly.
public enum PersistenceCodec {

    // MARK: - Encode

    /// Wraps a ``FailureRecord`` into the current versioned envelope.
    ///
    /// - Parameter record: The runtime failure record to persist.
    /// - Returns: A ``PersistedFailureRecordV1`` ready for serialization.
    public static func encode(_ record: FailureRecord) -> PersistedFailureRecordV1 {
        PersistedFailureRecordV1(
            recordFormatVersion: 1,
            traceFormatVersion: 1,
            propertyID: record.propertyID,
            trace: record.trace,
            errorMessage: record.errorMessage,
            runCount: record.runCount,
            shrinkCount: record.shrinkCount,
            timestamp: record.timestamp,
            engineVersion: record.engineVersion
        )
    }

    // MARK: - Decode

    /// Validates and converts a persisted envelope back to a ``FailureRecord``.
    ///
    /// - Parameter envelope: The deserialized versioned envelope.
    /// - Throws: ``PersistenceCompatibilityError`` if either format version
    ///   is outside the supported range.
    /// - Returns: A ``FailureRecord`` suitable for replay.
    public static func decode(
        _ envelope: PersistedFailureRecordV1
    ) throws -> FailureRecord {
        try validate(envelope)

        return FailureRecord(
            propertyID: envelope.propertyID,
            trace: envelope.trace,
            errorMessage: envelope.errorMessage,
            runCount: envelope.runCount,
            shrinkCount: envelope.shrinkCount,
            timestamp: envelope.timestamp,
            engineVersion: envelope.engineVersion
        )
    }

    // MARK: - Validation

    /// Checks that both format versions are within the supported ranges.
    ///
    /// - Parameter envelope: The envelope to validate.
    /// - Throws: ``PersistenceCompatibilityError`` on version mismatch.
    public static func validate(
        _ envelope: PersistedFailureRecordV1
    ) throws {
        let policy = PersistenceVersionPolicy.self

        guard
            policy.supportedRecordVersions.contains(
                envelope.recordFormatVersion
            )
        else {
            throw PersistenceCompatibilityError.unsupportedRecordVersion(
                found: envelope.recordFormatVersion,
                supported: policy.supportedRecordVersions
            )
        }

        guard
            policy.supportedTraceVersions.contains(
                envelope.traceFormatVersion
            )
        else {
            throw PersistenceCompatibilityError.unsupportedTraceVersion(
                found: envelope.traceFormatVersion,
                supported: policy.supportedTraceVersions
            )
        }
    }
}
