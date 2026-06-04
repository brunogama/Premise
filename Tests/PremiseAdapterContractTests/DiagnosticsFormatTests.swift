import Testing

@testable import PremiseCore
@testable import PremiseTesting
@testable import PremiseXCTest

// MARK: - Diagnostics Format Contract Tests

/// Verifies the exact structure of failure diagnostic output produced by
/// both formatters.
///
/// These tests act as a contract that protects downstream
/// tooling (CI parsers, IDE integrations) from unintentional format changes.
@Suite("Diagnostics Format")
struct DiagnosticsFormatTests {

  private static let testPropertyID = PropertyIdentity(
    fileID: "MyModule/PropertyTests.swift",
    line: 42,
    strategyLabel: "integers(in: 1...100)"
  )

  private static func makeRecord(
    errorMessage: String = "value 3 is not > 50",
    runCount: Int = 100,
    shrinkCount: Int = 7
  ) -> FailureRecord {
    FailureRecord(
      propertyID: testPropertyID,
      trace: ChoiceTrace(entries: []),
      errorMessage: errorMessage,
      runCount: runCount,
      shrinkCount: shrinkCount
    )
  }

  // MARK: - Line Structure

  @Test("Output contains the expected diagnostic sections")
  func outputLineCount() {
    let record = Self.makeRecord()
    let output = FailureFormatter.format(
      value: 3,
      record: record,
      propertyID: Self.testPropertyID
    )
    let lines = output.components(separatedBy: "\n")
    #expect(lines.count == 7)
  }

  @Test("First line contains property location")
  func firstLineContainsLocation() {
    let record = Self.makeRecord()
    let output = FailureFormatter.format(
      value: 3,
      record: record,
      propertyID: Self.testPropertyID
    )
    let firstLine = output.components(separatedBy: "\n")[0]
    #expect(firstLine == "Property failed: MyModule/PropertyTests.swift#42")
  }

  @Test("Second line contains counterexample value")
  func secondLineContainsCounterexample() {
    let record = Self.makeRecord()
    let output = FailureFormatter.format(
      value: 3,
      record: record,
      propertyID: Self.testPropertyID
    )
    let thirdLine = output.components(separatedBy: "\n")[2]
    #expect(thirdLine == "Minimal counterexample: 3")
  }

  @Test("Third line contains error message")
  func thirdLineContainsError() {
    let record = Self.makeRecord()
    let output = FailureFormatter.format(
      value: 3,
      record: record,
      propertyID: Self.testPropertyID
    )
    let fourthLine = output.components(separatedBy: "\n")[3]
    #expect(fourthLine == "Error: value 3 is not > 50")
  }

  @Test("Fourth line contains run and shrink counts")
  func fourthLineContainsCounts() {
    let record = Self.makeRecord()
    let output = FailureFormatter.format(
      value: 3,
      record: record,
      propertyID: Self.testPropertyID
    )
    let fifthLine = output.components(separatedBy: "\n")[4]
    #expect(fifthLine == "Runs: 100, Shrinks: 7")
  }

  @Test("Output contains failure kind trace size and replay instructions")
  func outputContainsReplayMetadata() {
    let record = Self.makeRecord()
    let output = FailureFormatter.format(
      value: 3,
      record: record,
      propertyID: Self.testPropertyID
    )
    #expect(output.contains("Failure kind: newFailure"))
    #expect(output.contains("Trace entries: 0"))
    #expect(output.contains("Replay:"))
    #expect(output.contains(".premise/examples"))
  }

  @Test("Output includes record statistics when report is absent")
  func outputIncludesRecordStatistics() {
    var statistics = RunStatistics()
    statistics.events = ["small", "small", "large"]
    statistics.notes = [RunNote(label: "bucket", value: "small")]
    statistics.targetScore = 2

    let record = FailureRecord(
      propertyID: Self.testPropertyID,
      trace: ChoiceTrace(entries: []),
      errorMessage: "value too small",
      runCount: 3,
      shrinkCount: 1,
      statistics: statistics
    )

    let output = FailureFormatter.format(
      value: 3,
      record: record,
      propertyID: Self.testPropertyID
    )

    #expect(output.contains("Events: large=1, small=2"))
    #expect(output.contains("Notes: bucket=small"))
    #expect(output.contains("Target score: 2.0"))
  }

  // MARK: - Value Rendering

  @Test("String counterexample renders with quotes removed")
  func stringCounterexampleRendering() {
    let record = Self.makeRecord(errorMessage: "bad string")
    let output = FailureFormatter.format(
      value: "hello world",
      record: record,
      propertyID: Self.testPropertyID
    )
    #expect(output.contains("hello world"))
  }

  @Test("Array counterexample renders bracket notation")
  func arrayCounterexampleRendering() {
    let record = Self.makeRecord(errorMessage: "bad array")
    let output = FailureFormatter.format(
      value: [1, 2, 3],
      record: record,
      propertyID: Self.testPropertyID
    )
    #expect(output.contains("[1, 2, 3]"))
  }

  // MARK: - Edge Cases

  @Test("Zero runs and zero shrinks format correctly")
  func zeroCountsFormat() {
    let record = Self.makeRecord(runCount: 0, shrinkCount: 0)
    let output = FailureFormatter.format(
      value: 0,
      record: record,
      propertyID: Self.testPropertyID
    )
    #expect(output.contains("Runs: 0, Shrinks: 0"))
  }

  @Test("Empty error message formats correctly")
  func emptyErrorMessageFormat() {
    let record = Self.makeRecord(errorMessage: "")
    let output = FailureFormatter.format(
      value: 0,
      record: record,
      propertyID: Self.testPropertyID
    )
    #expect(output.contains("Error: "))
  }

  @Test("XCTest formatter output matches swift-testing formatter for all edge cases")
  func xcTestEdgeCaseParity() {
    // swiftlint:disable:next large_tuple
    let edgeCases: [(Any, String, Int, Int)] = [
      (0, "", 0, 0),
      (Int.max, "overflow", 1, 1000),
      (-1, "negative", 999, 0),
    ]

    for (value, errorMsg, runs, shrinks) in edgeCases {
      let record = Self.makeRecord(
        errorMessage: errorMsg,
        runCount: runs,
        shrinkCount: shrinks
      )
      let stOutput = FailureFormatter.format(
        value: value,
        record: record,
        propertyID: Self.testPropertyID
      )
      let xcOutput = XCTestFailureFormatter.format(
        value: value,
        record: record,
        propertyID: Self.testPropertyID
      )
      #expect(stOutput == xcOutput)
    }
  }
}
