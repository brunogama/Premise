import PremiseCore
import PremiseParallel
import PremiseStrategies

let runner = ParallelRunner(
  strategy: Strategy<[UInt8]>.bytes(length: 1...256),
  config: PropertyConfig(maxRuns: 100),
  // Cap at 4 concurrent tasks — useful when runs open file handles
  // or allocate large buffers that would exhaust system resources.
  parallelConfig: ParallelConfig(maxConcurrentRuns: 4),
  propertyID: PropertyIdentity(fileID: #fileID, line: #line, strategyLabel: "bytes")
)
