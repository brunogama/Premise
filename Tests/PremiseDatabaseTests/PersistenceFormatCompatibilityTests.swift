import Foundation
import Testing

@testable import PremiseCore
@testable import PremiseDatabase

@Suite("PersistenceFormatCompatibilityTests")
struct PersistenceFormatCompatibilityTests {

  // MARK: - Helpers

  private func sampleStatistics() -> RunStatistics {
    RunStatistics(
      notes: [RunNote(label: "value", value: "42")],
      events: ["edge", "even"],
      targetScore: 42
    )
  }

  private func sampleRecord(
    statistics: RunStatistics = RunStatistics()
  ) -> FailureRecord {
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
      engineVersion: "0.2.0",
      statistics: statistics
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

  @Test("Envelope round-trip preserves non-empty run statistics")
  func roundTripPreservesNonEmptyStatistics() throws {
    let original = sampleRecord(statistics: sampleStatistics())
    let envelope = PersistenceCodec.encode(original)

    #expect(envelope.statistics == original.statistics)

    let decoded = try PersistenceCodec.decode(envelope)

    #expect(decoded == original)
    #expect(decoded.statistics == original.statistics)
  }

  @Test("Decode old envelope without statistics defaults to empty statistics")
  func oldEnvelopeWithoutStatisticsDefaultsToEmptyStatistics() throws {
    let original = sampleRecord(statistics: sampleStatistics())
    let envelope = PersistedFailureRecordV1(
      recordFormatVersion: 1,
      traceFormatVersion: 1,
      propertyID: original.propertyID,
      trace: original.trace,
      errorMessage: original.errorMessage,
      runCount: original.runCount,
      shrinkCount: original.shrinkCount,
      timestamp: original.timestamp,
      engineVersion: original.engineVersion
    )
    let data = try JSONEncoder().encode(envelope)
    let json = String(decoding: data, as: UTF8.self)

    #expect(!json.contains("statistics"))

    let decodedEnvelope = try JSONDecoder().decode(
      PersistedFailureRecordV1.self,
      from: data
    )
    let decoded = try PersistenceCodec.decode(decodedEnvelope)

    #expect(decodedEnvelope.statistics == nil)
    #expect(decoded.statistics == RunStatistics())
  }

  @Test("Persistence codec encodes and decodes trace blobs")
  func traceBlobRoundTrip() throws {
    let trace = sampleRecord().trace
    let blob = try PersistenceCodec.encodeTraceBlob(trace)
    let decoded = try PersistenceCodec.decodeTraceBlob(blob)

    #expect(blob.hasPrefix(ChoiceTrace.reproductionBlobPrefix))
    #expect(decoded == trace)
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
