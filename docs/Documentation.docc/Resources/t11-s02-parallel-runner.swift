import Testing
import PremiseCore
import PremiseParallel
import PremiseStrategies

func expensiveParse(_ bytes: [UInt8]) throws -> [String] {
  Thread.sleep(forTimeInterval: 0.05)
  return bytes.map { String($0, radix: 16) }
}

// Parallel: 100 runs on 8 cores ≈ 0.7 seconds (7x speedup on 8 cores).
@Test func parserNeverCrashes() async throws {
  let propertyID = PropertyIdentity(
    fileID: #fileID,
    line: #line,
    strategyLabel: "bytes"
  )
  let runner = ParallelRunner(
    strategy: Strategy<[UInt8]>.bytes(length: 1...256),
    config: PropertyConfig(maxRuns: 100),
    propertyID: propertyID
  )
  let result = try await runner.run { bytes in
    let parsed = try expensiveParse(bytes)
    guard !parsed.isEmpty else {
      throw PropertyViolation("empty result for \(bytes.count) bytes")
    }
  }
  if case .failure(let record, let value) = result {
    Issue.record("Failed with \(value): \(record.errorMessage)")
  }
}

struct PropertyViolation: Error {
  let message: String
  init(_ msg: String) { message = msg }
}
