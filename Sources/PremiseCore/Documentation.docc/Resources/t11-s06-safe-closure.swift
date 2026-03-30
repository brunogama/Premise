import PremiseParallel
import PremiseStrategies

let runner = ParallelRunner(
  strategy: Strategy<[UInt8]>.bytes(length: 1...512),
  config: .default,
  propertyID: .init(fileID: #fileID, line: #line, strategyLabel: "bytes")
)

// Safe: pure computation, no shared state.
let result = try await runner.run { bytes in
  let hash1 = myHash(bytes)
  let hash2 = myHash(bytes)
  // A hash function must be deterministic.
  guard hash1 == hash2 else { throw HashError.nonDeterministic }
}

func myHash(_ bytes: [UInt8]) -> UInt64 {
  bytes.reduce(0) { acc, b in acc &* 31 &+ UInt64(b) }
}
enum HashError: Error { case nonDeterministic }
