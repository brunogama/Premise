import Testing
import PremiseTesting
import PremiseStrategies

// Simulate an expensive operation (e.g. parsing a complex binary format).
func expensiveParse(_ bytes: [UInt8]) throws -> [String] {
  // ... takes ~50ms per call ...
  Thread.sleep(forTimeInterval: 0.05)
  return bytes.map { String($0, radix: 16) }
}

// Sequential: 100 runs × 50ms ≈ 5 seconds.
@Test func parserNeverCrashes() async throws {
  try await forAll(.bytes(length: 1...256)) { bytes in
    let result = try expensiveParse(bytes)
    #expect(!result.isEmpty)
  }
}
