import Foundation
import Testing

@testable import PremiseCore
@testable import PremiseDatabase

@Suite("PersistenceFormatCompatibilityTests")
struct PersistenceFormatCompatibilityTests {

  // MARK: - Helpers

  private func sampleRecord() -> FailureRecord {
    let trace = ChoiceTrace(
      entries: [.integer(42), .boolean(true)],
      spans: [ChoiceTrace.Span(label: "root", start: 0, end: 2)]
    )
    return FailureRecord(
      propertyID: PropertyIdentity(
        fileID: "Tests/Sample.swift",
        line: 10,
        strategyLabel: "integers"
      ),
      trace: trace,
      errorMessage: "value exceeded limit",
      runCount: 5,
      shrinkCount: 3,
      timestamp: Date(timeIntervalSince1970: 1_000_000),
      engineVersion: "0.2.0"
    )
  }

  // MARK: - Tests

  @Test("Envelope round-trip preserves all FailureRecord fields")
  func roundTripPreservesAllFields() throws {
    let original = sampleRecord()
    let envelope = PersistenceCodec.encode(original)

    #expect(envelope.recordFormatVersion == 1)
    #expect(envelope.traceFormatVersion == 1)

    let decoded = try PersistenceCodec.decode(envelope)

    #expect(decoded == original)
    #expect(decoded.propertyID == original.propertyID)
    #expect(decoded.trace == original.trace)
    #expect(decoded.errorMessage == original.errorMessage)
    #expect(decoded.runCount == original.runCount)
    #expect(decoded.shrinkCount == original.shrinkCount)
    #expect(decoded.timestamp == original.timestamp)
    #expect(decoded.engineVersion == original.engineVersion)
  }

  @Test("Decode rejects unsupported trace format version")
  func unsupportedTraceVersionThrows() throws {
    let original = sampleRecord()
    let envelope = PersistedFailureRecordV1(
      recordFormatVersion: 1,
      traceFormatVersion: 2,
      propertyID: original.propertyID,
      trace: original.trace,
      errorMessage: original.errorMessage,
      runCount: original.runCount,
      shrinkCount: original.shrinkCount,
      timestamp: original.timestamp,
      engineVersion: original.engineVersion
    )

    #expect(throws: PersistenceCompatibilityError.self) {
      try PersistenceCodec.decode(envelope)
    }

    do {
      _ = try PersistenceCodec.decode(envelope)
    } catch let error as PersistenceCompatibilityError {
      #expect(
        error
          == .unsupportedTraceVersion(
            found: 2,
            supported: 1...1
          )
      )
    }
  }

  @Test("Decode rejects unsupported record format version")
  func unsupportedRecordVersionThrows() throws {
    let original = sampleRecord()
    let envelope = PersistedFailureRecordV1(
      recordFormatVersion: 2,
      traceFormatVersion: 1,
      propertyID: original.propertyID,
      trace: original.trace,
      errorMessage: original.errorMessage,
      runCount: original.runCount,
      shrinkCount: original.shrinkCount,
      timestamp: original.timestamp,
      engineVersion: original.engineVersion
    )

    #expect(throws: PersistenceCompatibilityError.self) {
      try PersistenceCodec.decode(envelope)
    }

    do {
      _ = try PersistenceCodec.decode(envelope)
    } catch let error as PersistenceCompatibilityError {
      #expect(
        error
          == .unsupportedRecordVersion(
            found: 2,
            supported: 1...1
          )
      )
    }
  }
}
