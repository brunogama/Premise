import Testing

@testable import PremiseCore
@testable import PremiseTesting
@testable import PremiseXCTest

// MARK: - Diagnostics Format Contract Tests

/// Verifies the exact structure of failure diagnostic output produced by
/// both formatters. These tests act as a contract that protects downstream
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

  @Test("Output contains exactly five lines")
  func outputLineCount() {
    let record = Self.makeRecord()
    let output = FailureFormatter.format(
      value: 3,
      record: record,
      propertyID: Self.testPropertyID
    )
    let lines = output.components(separatedBy: "\n")
    #expect(lines.count == 5)
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
    let secondLine = output.components(separatedBy: "\n")[1]
    #expect(secondLine == "Counterexample: 3")
  }

  @Test("Third line contains error message")
  func thirdLineContainsError() {
    let record = Self.makeRecord()
    let output = FailureFormatter.format(
      value: 3,
      record: record,
      propertyID: Self.testPropertyID
    )
    let thirdLine = output.components(separatedBy: "\n")[2]
    #expect(thirdLine == "Error: value 3 is not > 50")
  }

  @Test("Fourth line contains run and shrink counts")
  func fourthLineContainsCounts() {
    let record = Self.makeRecord()
    let output = FailureFormatter.format(
      value: 3,
      record: record,
      propertyID: Self.testPropertyID
    )
    let fourthLine = output.components(separatedBy: "\n")[3]
    #expect(fourthLine == "Runs: 100, Shrinks: 7")
  }

  @Test("Fifth line contains replay instructions")
  func fifthLineContainsReplay() {
    let record = Self.makeRecord()
    let output = FailureFormatter.format(
      value: 3,
      record: record,
      propertyID: Self.testPropertyID
    )
    let fifthLine = output.components(separatedBy: "\n")[4]
    #expect(fifthLine.hasPrefix("Replay:"))
    #expect(fifthLine.contains(".premise/examples"))
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
    let secondLine = output.components(separatedBy: "\n")[1]
    #expect(secondLine.contains("hello world"))
  }

  @Test("Array counterexample renders bracket notation")
  func arrayCounterexampleRendering() {
    let record = Self.makeRecord(errorMessage: "bad array")
    let output = FailureFormatter.format(
      value: [1, 2, 3],
      record: record,
      propertyID: Self.testPropertyID
    )
    let secondLine = output.components(separatedBy: "\n")[1]
    #expect(secondLine.contains("[1, 2, 3]"))
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
    let fourthLine = output.components(separatedBy: "\n")[3]
    #expect(fourthLine == "Runs: 0, Shrinks: 0")
  }

  @Test("Empty error message formats correctly")
  func emptyErrorMessageFormat() {
    let record = Self.makeRecord(errorMessage: "")
    let output = FailureFormatter.format(
      value: 0,
      record: record,
      propertyID: Self.testPropertyID
    )
    let thirdLine = output.components(separatedBy: "\n")[2]
    #expect(thirdLine == "Error: ")
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
