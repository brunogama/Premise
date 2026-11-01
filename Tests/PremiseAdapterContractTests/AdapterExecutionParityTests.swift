import Foundation
import Testing

@testable import PremiseCore
@testable import PremiseDatabase
@testable import PremiseStrategies

// MARK: - Adapter Execution Parity Contract Tests

/// Verifies that both adapters (swift-testing and XCTest) share identical
/// execution behavior by testing the underlying `Runner` and
/// `ReplayFirstExecutor` directly.
///
/// Both adapters delegate to the same pipeline, so exercising the shared path
/// proves behavioral equivalence.
@Suite("Adapter Execution Parity")
struct AdapterExecutionParityTests {

  private static func makeRunner(
    range: ClosedRange<Int> = 1...10,
    config: PropertyConfig = .default
  ) -> Runner<Int> {
    let strategy = Strategy<Int>.integers(in: range)
    let pid = PropertyIdentity(
      fileID: "ContractTests/Parity.swift",
      line: 1,
      strategyLabel: strategy.label
    )
    return Runner(strategy: strategy, config: config, propertyID: pid)
  }

  @Test("Runner returns .passed for a trivially true property")
  func passingPropertyResult() async {
    let runner = Self.makeRunner()
    let result = await runner.run({ _ in () })
    guard case .passed(let runs) = result else {
      Issue.record("Expected .passed, got failure")
      return
    }
    #expect(runs == PropertyConfig.default.maxRuns)
  }

  @Test("Runner returns .failure for a trivially false property")
  func failingPropertyResult() async {
    let runner = Self.makeRunner()
    let result = await runner.run({ _ in
      throw ContractTestError(message: "always fails")
    })
    guard case .failure(let record, value: let value) = result else {
      Issue.record("Expected .failure, got .passed")
      return
    }
    #expect(value == 1)  // integers(in: 1...10) returns lowerBound
    #expect(record.runCount == 1)
    #expect(record.errorMessage == "always fails")
  }

  @Test("Two runners with same config produce identical results")
  func deterministicExecution() async {
    let config = PropertyConfig(maxRuns: 50, seed: 42)
    let runner1 = Self.makeRunner(config: config)
    let runner2 = Self.makeRunner(config: config)

    let result1 = await runner1.run({ value in
      guard value > 5 else {
        throw ContractTestError(message: "too small: \(value)")
      }
    })
    let result2 = await runner2.run({ value in
      guard value > 5 else {
        throw ContractTestError(message: "too small: \(value)")
      }
    })

    Self.expectMatchingResults(result1, result2)
  }

  private static func expectMatchingResults(
    _ result1: RunResult<Int>,
    _ result2: RunResult<Int>
  ) {
    switch (result1, result2) {
    case (.passed(let firstRuns), .passed(let secondRuns)):
      #expect(firstRuns == secondRuns)

    case (
      .failure(let firstRecord, value: let firstValue),
      .failure(let secondRecord, value: let secondValue)
    ):
      #expect(firstValue == secondValue)
      #expect(firstRecord.errorMessage == secondRecord.errorMessage)
      #expect(firstRecord.runCount == secondRecord.runCount)
      #expect(firstRecord.shrinkCount == secondRecord.shrinkCount)

    default:
      Issue.record("Results diverged: \(result1) vs \(result2)")
    }
  }
}

extension AdapterExecutionParityTests {
  @Test("ReplayFirstExecutor passes through Runner result for passing property")
  func executorPassingProperty() async throws {
    let runner = Self.makeRunner(config: PropertyConfig(maxRuns: 10))
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let database = FileBackedDatabase(rootDirectory: directory)
    let executor = ReplayFirstExecutor(runner: runner, database: database)

    let result = try await executor.execute({ _ in () })

    guard case .passed(let runs) = result else {
      Issue.record("Expected .passed from executor")
      return
    }
    #expect(runs == 10)
  }

  @Test("ReplayFirstExecutor passes through Runner result for failing property")
  func executorFailingProperty() async throws {
    let runner = Self.makeRunner(config: PropertyConfig(maxRuns: 10))
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let database = FileBackedDatabase(rootDirectory: directory)
    let executor = ReplayFirstExecutor(runner: runner, database: database)

    let result = try await executor.execute({ _ in
      throw ContractTestError(message: "executor fail")
    })

    guard case .failure(let record, value: _) = result else {
      Issue.record("Expected .failure from executor")
      return
    }
    #expect(record.errorMessage == "executor fail")
  }

  @Test("ReplayFirstExecutor returns detailed reports for async properties")
  func executorAsyncDetailedProperty() async throws {
    let runner = Self.makeRunner(config: PropertyConfig(maxRuns: 10, seed: 3))
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let database = FileBackedDatabase(rootDirectory: directory)
    let executor = ReplayFirstExecutor(runner: runner, database: database)
    let property: @Sendable (Int) async throws -> Void = { _ in
      throw ContractTestError(message: "async detailed fail")
    }

    let result = try await executor.executeDetailed(property)

    guard case .failure(let record, value: _, report: let report) = result
    else {
      Issue.record("Expected detailed async failure from executor")
      return
    }
    #expect(record.errorMessage == "async detailed fail")
    #expect(report.runCount == 1)
    #expect(report.phaseCounts[.generate] == 1)
  }

  @Test("FailureRecord captures property identity correctly")
  func failureRecordIdentity() async {
    let strategy = Strategy<Int>.integers(in: 0...100)
    let pid = PropertyIdentity(
      fileID: "Module/Test.swift",
      line: 55,
      strategyLabel: strategy.label
    )
    let runner = Runner(strategy: strategy, propertyID: pid)

    let result = await runner.run({ _ in
      throw ContractTestError(message: "id check")
    })

    guard case .failure(let record, value: _) = result else {
      Issue.record("Expected failure")
      return
    }
    #expect(record.propertyID == pid)
    #expect(record.propertyID.fileID == "Module/Test.swift")
    #expect(record.propertyID.line == 55)
  }
}
