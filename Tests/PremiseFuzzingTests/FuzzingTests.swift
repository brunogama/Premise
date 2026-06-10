import Foundation
import Testing

@testable import PremiseCore
@testable import PremiseDatabase
@testable import PremiseFuzzing
@testable import PremiseStrategies

private enum FuzzingTestError: Error, CustomStringConvertible, Sendable {
  case propertyFailed
  case unexpectedExecution

  var description: String {
    switch self {
    case .propertyFailed: return "property failed"
    case .unexpectedExecution: return "unexpected execution"
    }
  }
}

@Test("FuzzInputProvider draws bytes deterministically")
func fuzzInputProviderDrawsBytesDeterministically() {
  var provider = FuzzInputProvider(bytes: [0x34, 0x12, 0xFF])

  #expect(provider.drawBits(count: 16) == 0x1234)
  #expect(provider.drawBytes(count: 1) == [0xFF])
  #expect(provider.drawBits(count: 8) == 0)
  #expect(provider.isExhausted)
}

@Test("fuzzOneInput runs generated values")
func fuzzOneInputRunsGeneratedValues() async throws {
  let result = try await fuzzOneInput(
    Data([7]),
    strategy: Strategy<Int>.integers(in: 0...10),
    config: FuzzConfig().withoutPersistence()
  ) { value in
    #expect((0...10).contains(value))
  }

  #expect(result.outcome == .passed)
  #expect(result.inputByteCount == 1)
  #expect(!result.trace.entries.isEmpty)
}

@Test("fuzzOneInput reports exhausted inputs")
func fuzzOneInputReportsExhaustedInputs() async throws {
  let result = try await fuzzOneInput(
    Data(),
    strategy: Strategy<Int>.integers(in: 0...10),
    config: FuzzConfig().withoutPersistence()
  ) { _ in
    throw FuzzingTestError.unexpectedExecution
  }

  #expect(result.outcome == .exhausted)
}

@Test("fuzzOneInput treats rejected draws as invalid input")
func fuzzOneInputTreatsRejectedDrawsAsInvalidInput() async throws {
  let result = try await fuzzOneInput(
    Data([1]),
    strategy: Strategy<Int>.nothing(),
    config: FuzzConfig().withoutPersistence()
  ) { _ in
    throw FuzzingTestError.unexpectedExecution
  }

  #expect(result.outcome == .rejected)
  #expect(result.rejectionReason?.contains("does not produce examples") == true)
}

@Test("fuzzOneInput saves failures to database")
func fuzzOneInputSavesFailuresToDatabase() async throws {
  let propertyID = PropertyIdentity(
    fileID: "FuzzingTests.swift",
    line: 1,
    strategyLabel: "fuzz-one-input",
    functionName: "fuzzOneInputSavesFailuresToDatabase"
  )
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  let config = FuzzConfig(propertyID: propertyID, databaseDirectory: directory)

  do {
    try await fuzzOneInput(
      Data([3]),
      strategy: Strategy<Int>.integers(in: 0...10),
      config: config
    ) { _ in
      throw FuzzingTestError.propertyFailed
    }
    #expect(Bool(false))
  } catch let failure as FuzzFailure {
    #expect(failure.input == [3])
    #expect(failure.underlyingDescription.contains("property failed"))
  }

  let traces = try await FileBackedDatabase(rootDirectory: directory).loadTraces(for: propertyID)
  #expect(!traces.isEmpty)
}
