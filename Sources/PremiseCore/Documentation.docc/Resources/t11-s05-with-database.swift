import PremiseCore
import PremiseDatabase
import PremiseParallel
import PremiseStrategies

let propertyID = PropertyIdentity(fileID: #fileID, line: #line, strategyLabel: "bytes")

// Pass a FileBackedDatabase to get replay-first semantics.
// Stored traces are replayed sequentially before parallel generation.
let runner = ParallelRunner(
  strategy: Strategy<[UInt8]>.bytes(length: 1...256),
  config: PropertyConfig(maxRuns: 100),
  parallelConfig: ParallelConfig(maxConcurrentRuns: 4),
  propertyID: propertyID,
  database: FileBackedDatabase()  // ← add persistence
)
