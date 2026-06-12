import Foundation
import Testing

@testable import PremiseCore
@testable import PremiseStrategies
@testable import PremiseTesting

private enum ConvenienceTestError: Error {
  case duplicateInsert
}

private actor CounterSystem {
  private var values: Set<Int> = []

  func insert(_ value: Int) throws {
    guard !values.contains(value) else {
      throw ConvenienceTestError.duplicateInsert
    }
    values.insert(value)
  }

  func remove(_ value: Int) {
    values.remove(value)
  }

  func snapshot() -> Set<Int> {
    values
  }
}

private enum CounterCommand: StatefulCommand {
  case insert(Int)
  case duplicateInsert(Int)
  case remove(Int)

  var label: String {
    switch self {
    case .insert(let value): "insert(\(value))"
    case .duplicateInsert(let value): "duplicateInsert(\(value))"
    case .remove(let value): "remove(\(value))"
    }
  }

  var expectation: CommandExpectation {
    switch self {
    case .duplicateInsert: .fails
    case .insert, .remove: .succeeds
    }
  }

  func canApply(to model: Set<Int>) -> Bool {
    switch self {
    case .insert(let value): !model.contains(value)
    case .duplicateInsert(let value): model.contains(value)
    case .remove(let value): model.contains(value)
    }
  }

  func apply(to model: inout Set<Int>) throws {
    switch self {
    case .insert(let value): model.insert(value)
    case .duplicateInsert: break
    case .remove(let value): model.remove(value)
    }
  }

  func run(on system: CounterSystem) async throws {
    switch self {
    case .insert(let value): try await system.insert(value)
    case .duplicateInsert(let value): try await system.insert(value)
    case .remove(let value): await system.remove(value)
    }
  }
}

@Test("expectForAll accepts Boolean predicates")
func expectForAllAcceptsBooleanPredicates() async throws {
  try await expectForAll(
    Strategy<Int>.integers(in: 0...5),
    config: .bounded(runs: 5, shrinks: 10, replay: false)
  ) { value in
    value >= 0 && value <= 5
  }
}

@Test("expectForAll reports false predicates as property failures")
func expectForAllReportsFalsePredicates() async throws {
  await withKnownIssue {
    try await expectForAll(
      Strategy<Int>.just(1),
      config: .bounded(runs: 1, replay: false)
    ) { value in
      value == 2
    }
  }
}

@Test("data-aware expectForAll can annotate reports")
func dataAwareExpectForAllCanAnnotateReports() async throws {
  try await expectForAll(
    Strategy<Int>.integers(in: 0...3),
    config: .bounded(runs: 5, replay: false)
  ) { value, data in
    data.note("value", value: value)
    data.event(value.isMultiple(of: 2) ? "even" : "odd")
    return (0...3).contains(value)
  }
}

@Test("temporary file helper writes and cleans up fixtures")
func temporaryFileHelperWritesAndCleansUpFixtures() async throws {
  let contents = Data("hello".utf8)
  let result = try await withTemporaryFile(contents: contents, extension: "txt") { url in
    #expect(url.pathExtension == "txt")
    return (try Data(contentsOf: url), url)
  }

  #expect(result.0 == contents)
  #expect(!FileManager.default.fileExists(atPath: result.1.path))
}

@Test("round trip helper checks encode decode equivalence")
func roundTripHelperChecksEncodeDecodeEquivalence() async throws {
  try await expectRoundTrip(
    Strategy<Int>.integers(in: 0...10),
    config: .bounded(runs: 5, replay: false),
    encode: { String($0) },
    decode: { Int($0) ?? -1 },
    equivalent: { original, decoded in original == decoded }
  )
}

@Test("model agreement helper compares model and implementation")
func modelAgreementHelperComparesModelAndImplementation() async throws {
  try await expectModelAgreement(
    Strategy<Int>.integers(in: 0...10),
    config: .bounded(runs: 5, replay: false),
    model: { $0 * $0 },
    actual: { value in
      await Task.yield()
      return value * value
    },
    equivalent: { expected, observed in expected == observed }
  )
}

@Test("stateful command checker handles expected failures")
func statefulCommandCheckerHandlesExpectedFailures() async throws {
  try await checkStateMachine(
    commands: [
      .insert(1),
      .duplicateInsert(1),
      .insert(2),
      .remove(1),
    ],
    initialModel: Set<Int>(),
    makeSystem: { CounterSystem() }
  ) { model, system in
    #expect(await system.snapshot() == model)
  }
}
