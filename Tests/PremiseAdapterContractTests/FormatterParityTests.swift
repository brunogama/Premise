import Testing

@testable import PremiseCore
@testable import PremiseTesting
@testable import PremiseXCTest

// MARK: - Formatter Parity Contract Tests

/// Verifies that `FailureFormatter` (swift-testing) and
/// `XCTestFailureFormatter` (XCTest) produce identical diagnostic output
/// for the same inputs, ensuring users see consistent failure messages
/// regardless of which test framework they choose.
@Suite("Formatter Parity")
struct FormatterParityTests {

  private static func makePropertyID(
    fileID: String = "TestModule/File.swift",
    line: UInt = 42,
    label: String = "integers(in: 1...10)"
  ) -> PropertyIdentity {
    PropertyIdentity(fileID: fileID, line: line, strategyLabel: label)
  }

  private static func makeRecord(
    propertyID: PropertyIdentity,
    errorMessage: String = "value 1 is not > 5",
    statistics: RunStatistics = RunStatistics()
  ) -> FailureRecord {
    FailureRecord(
      propertyID: propertyID,
      trace: ChoiceTrace(entries: []),
      errorMessage: errorMessage,
      runCount: 100,
      shrinkCount: 3,
      statistics: statistics
    )
  }

  private static func makeStatistics() -> RunStatistics {
    RunStatistics(
      notes: [RunNote(label: "bucket", value: "small")],
      events: ["small", "small", "large"],
      targetScore: 2
    )
  }

  private static func makeReport(statistics: RunStatistics) -> RunReport {
    RunReport(
      runCount: 3,
      events: ["small": 2, "large": 1],
      notes: statistics.notes,
      maxTargetScore: statistics.targetScore,
      healthWarnings: [
        HealthWarning(
          check: .excessiveFiltering,
          message: "More than half of generated examples were rejected."
        )
      ]
    )
  }

  private static func makeReproductionRecord(
    propertyID: PropertyIdentity
  ) -> FailureRecord {
    FailureRecord(
      propertyID: propertyID,
      trace: ChoiceTrace(entries: [.integer(7)]),
      errorMessage: "value 7 failed",
      runCount: 1,
      shrinkCount: 0
    )
  }

  private static func makeContext(
    record: FailureRecord,
    propertyID: PropertyIdentity,
    report: RunReport
  ) -> XCTestFailureContext {
    XCTestFailureContext(record: record, propertyID: propertyID, report: report)
  }
  @Test("Both formatters produce identical output for integer counterexample")
  func integerCounterexampleParity() {
    let pid = Self.makePropertyID()
    let record = Self.makeRecord(propertyID: pid)

    let swiftTestingOutput = FailureFormatter.format(
      value: 1,
      record: record,
      propertyID: pid
    )
    let xcTestOutput = XCTestFailureFormatter.format(
      value: 1,
      context: XCTestFailureContext(record: record, propertyID: pid)
    )

    #expect(swiftTestingOutput == xcTestOutput)
  }
}

extension FormatterParityTests {
  @Test("Both formatters produce identical output for string counterexample")
  func stringCounterexampleParity() {
    let pid = Self.makePropertyID(label: "strings")
    let record = Self.makeRecord(
      propertyID: pid,
      errorMessage: "string too short"
    )

    let swiftTestingOutput = FailureFormatter.format(
      value: "abc",
      record: record,
      propertyID: pid
    )
    let xcTestOutput = XCTestFailureFormatter.format(
      value: "abc",
      context: XCTestFailureContext(record: record, propertyID: pid)
    )

    #expect(swiftTestingOutput == xcTestOutput)
  }

  @Test("Both formatters produce identical output with zero shrinks")
  func zeroShrinksParity() {
    let pid = Self.makePropertyID()
    let record = FailureRecord(
      propertyID: pid,
      trace: ChoiceTrace(entries: []),
      errorMessage: "value 1 is not > 5",
      runCount: 1,
      shrinkCount: 0
    )

    let swiftTestingOutput = FailureFormatter.format(
      value: 99,
      record: record,
      propertyID: pid
    )
    let xcTestOutput = XCTestFailureFormatter.format(
      value: 99,
      context: XCTestFailureContext(record: record, propertyID: pid)
    )

    #expect(swiftTestingOutput == xcTestOutput)
  }

  @Test("Both formatters produce identical output with custom file location")
  func customFileLocationParity() {
    let pid = Self.makePropertyID(
      fileID: "MyApp/Models/User.swift",
      line: 200,
      label: "users"
    )
    let record = Self.makeRecord(
      propertyID: pid,
      errorMessage: "invalid user state"
    )

    let swiftTestingOutput = FailureFormatter.format(
      value: "invalid",
      record: record,
      propertyID: pid
    )
    let xcTestOutput = XCTestFailureFormatter.format(
      value: "invalid",
      context: XCTestFailureContext(record: record, propertyID: pid)
    )

    #expect(swiftTestingOutput == xcTestOutput)
  }

  @Test("Both formatters produce identical output with record statistics")
  func recordStatisticsParity() {
    let pid = Self.makePropertyID()
    let record = Self.makeRecord(
      propertyID: pid,
      statistics: Self.makeStatistics()
    )

    let swiftTestingOutput = FailureFormatter.format(
      value: 1,
      record: record,
      propertyID: pid
    )
    let xcTestOutput = XCTestFailureFormatter.format(
      value: 1,
      context: XCTestFailureContext(record: record, propertyID: pid)
    )

    #expect(swiftTestingOutput == xcTestOutput)
    #expect(swiftTestingOutput.contains("Events: large=1, small=2"))
    #expect(swiftTestingOutput.contains("Notes: bucket=small"))
    #expect(swiftTestingOutput.contains("Target score: 2.0"))
  }

}

extension FormatterParityTests {
  @Test("Both formatters produce identical reproduction blob output")
  func reproductionBlobParity() {
    let pid = Self.makePropertyID()
    let record = Self.makeReproductionRecord(propertyID: pid)

    let swiftTestingOutput = FailureFormatter.format(
      value: 7,
      record: record,
      propertyID: pid,
      includeReproductionBlob: true
    )
    let xcTestOutput = XCTestFailureFormatter.format(
      value: 7,
      context: XCTestFailureContext(
        record: record,
        propertyID: pid,
        includeReproductionBlob: true
      )
    )

    #expect(swiftTestingOutput == xcTestOutput)
    #expect(swiftTestingOutput.contains("Reproduction blob: premise-trace-v1:"))
  }

  @Test("Both formatters produce identical output with report statistics")
  func reportStatisticsParity() {
    let id = Self.makePropertyID()
    let statistics = Self.makeStatistics()
    let record = Self.makeRecord(propertyID: id, statistics: statistics)
    let report = Self.makeReport(statistics: statistics)

    let swiftTestingOutput = FailureFormatter.format(
      value: 1,
      record: record,
      propertyID: id,
      report: report
    )
    let xcTestOutput = XCTestFailureFormatter.format(
      value: 1,
      context: Self.makeContext(record: record, propertyID: id, report: report)
    )

    #expect(swiftTestingOutput == xcTestOutput)
    #expect(swiftTestingOutput.contains("Events: large=1, small=2"))
    #expect(swiftTestingOutput.contains("Health warnings: excessiveFiltering"))
  }
}
