import PremiseCore
import PremiseStrategies

// A simplified JSON value type.
indirect enum JSON: Sendable, Equatable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([Self])
  case object([String: Self])
}

let letters = Array("abcdefghijklmnopqrstuvwxyz")
let keyStrategy = Strategy<String>.strings(from: letters, length: 1...8)

let jsonStrategy = Strategy<JSON>.recursive(
  RecursiveStrategyConfig(depth: 3, desiredSize: 5, expectedBranchSize: 1),
  leaf: Strategy<JSON>.oneOf([
    .just(.null),
    Strategy<Bool>.booleans.map { .bool($0) },
    Strategy<Double>.floats(in: -1e6...1e6).map { .number($0) },
    keyStrategy.map { .string($0) },
  ])
) { smaller in
  Strategy<JSON>.oneOf([
    Strategy<[JSON]>.arrays(of: smaller, length: 0...3).map { .array($0) },
    Strategy<[String: JSON]>.dictionaries(
      keys: keyStrategy,
      values: smaller,
      count: 0...3
    ).map { .object($0) },
  ])
}
