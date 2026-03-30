import Testing

@testable import ConjectureCore
@testable import ConjectureTesting
@testable import ConjectureXCTest

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
        runCount: Int = 100,
        shrinkCount: Int = 3
    ) -> FailureRecord {
        FailureRecord(
            propertyID: propertyID,
            trace: ChoiceTrace(entries: []),
            errorMessage: errorMessage,
            runCount: runCount,
            shrinkCount: shrinkCount
        )
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
            record: record,
            propertyID: pid
        )

        #expect(swiftTestingOutput == xcTestOutput)
    }

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
            record: record,
            propertyID: pid
        )

        #expect(swiftTestingOutput == xcTestOutput)
    }

    @Test("Both formatters produce identical output with zero shrinks")
    func zeroShrinksParity() {
        let pid = Self.makePropertyID()
        let record = Self.makeRecord(
            propertyID: pid,
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
            record: record,
            propertyID: pid
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
            record: record,
            propertyID: pid
        )

        #expect(swiftTestingOutput == xcTestOutput)
    }
}
