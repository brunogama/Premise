import PremiseParallel
import PremiseStrategies

// Actor access is safe: each await serialises through the actor.
// Beware: heavy contention on a single actor can reduce parallelism.
actor MetricsCollector {
  private(set) var count = 0
  func increment() { count += 1 }
}

let metrics = MetricsCollector()
let runner = ParallelRunner(
  strategy: Strategy<Int>.integers(in: 0...1000),
  config: .default,
  propertyID: .init(fileID: #fileID, line: #line, strategyLabel: "integers")
)

let result = try await runner.run { value in
  await metrics.increment()  // actor access — safe under Swift 6
  guard isValid(value) else { throw ValidationError() }
}

func isValid(_ n: Int) -> Bool { n >= 0 }
struct ValidationError: Error {}
