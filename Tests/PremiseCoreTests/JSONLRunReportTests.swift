import Foundation
import Testing

@testable import PremiseCore
@testable import PremiseStrategies
@Test("JSONL run output writes structured run events")
func jsonlRunOutputWritesStructuredRunEvents() async throws {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  let outputURL = directory.appendingPathComponent("premise-runs.jsonl")
  let propertyID = PropertyIdentity(
    fileID: "PhaseAndReportTests.swift",
    line: 321,
    strategyLabel: "just(1)",
    functionName: "jsonlRunOutputWritesStructuredRunEvents"
  )
  let runner = makeJSONLRunner(outputURL: outputURL, propertyID: propertyID)

  let result = await runner.runDetailed { _ in
    // The passing run writes its event.
  }
  guard case .passed = result else {
    Issue.record("Expected JSONL output run to pass")
    return
  }

  let output = try String(contentsOf: outputURL, encoding: .utf8)
  let lines = output.split(separator: "\n")
  #expect(lines.count == 1)

  try verifyPassedEvent(lines[0], propertyID: propertyID)
}

private func makeJSONLRunner(
  outputURL: URL,
  propertyID: PropertyIdentity
) -> Runner<Int> {
  Runner(
    strategy: Strategy<Int>.just(1),
    config: PropertyConfig(maxRuns: 1, seed: 1).writingJSONLines(to: outputURL),
    propertyID: propertyID
  )
}

private func verifyPassedEvent(
  _ line: Substring,
  propertyID: PropertyIdentity
) throws {
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .iso8601
  let event = try decoder.decode(RunJSONLEvent.self, from: Data(line.utf8))
  #expect(event.event == "premise.run")
  #expect(event.propertyID == propertyID)
  #expect(event.outcome == .passed)
  #expect(event.runCount == 1)
}

@Test("Concurrent JSONL appends write complete decodable lines")
func concurrentJSONLAppendsWriteCompleteLines() async throws {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  let outputURL = directory.appendingPathComponent("premise-runs.jsonl")
  let eventCount = 64

  try await withThrowingTaskGroup(of: Void.self) { group in
    for index in 0..<eventCount {
      let event = makeConcurrentEvent(index: index)

      group.addTask {
        try RunJSONLWriter.append(event, to: outputURL)
      }
    }

    try await group.waitForAll()
  }

  let output = try String(contentsOf: outputURL, encoding: .utf8)
  let lines = output.split(separator: "\n")
  #expect(lines.count == eventCount)

  try verifyConcurrentEvents(lines, count: eventCount)
}


private func makeConcurrentEvent(index: Int) -> RunJSONLEvent {
  let propertyID = PropertyIdentity(
    fileID: "PhaseAndReportTests.swift",
    line: UInt(400 + index),
    strategyLabel: "just(\(index))",
    functionName: "concurrentJSONLAppendsWriteCompleteLines-\(index)"
  )
  let report = RunReport(runCount: 1, phaseCounts: [.generate: 1])
  return RunJSONLEvent(
    propertyID: propertyID,
    result: DetailedRunResult<Int>.passed(report)
  )
}

private func verifyConcurrentEvents(
  _ lines: [Substring],
  count: Int
) throws {
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .iso8601
  var functionNames: Set<String> = []
  for line in lines {
    let event = try decoder.decode(RunJSONLEvent.self, from: Data(line.utf8))
    #expect(event.event == "premise.run")
    #expect(event.outcome == .passed)
    #expect(event.runCount == 1)
    if let functionName = event.propertyID.functionName {
      functionNames.insert(functionName)
    }
  }
  #expect(functionNames.count == count)
}
