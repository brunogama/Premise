import PremiseCore

/// Configuration for recursive strategy generation.
public struct RecursiveStrategyConfig: Sendable {
  /// Maximum recursive depth.
  public var depth: Int
  /// Relative weight of choosing a leaf.
  public var desiredSize: Int
  /// Relative weight of choosing a branch.
  public var expectedBranchSize: Int

  /// Creates a recursive strategy configuration.
  public init(depth: Int, desiredSize: Int, expectedBranchSize: Int) {
    self.depth = depth
    self.desiredSize = desiredSize
    self.expectedBranchSize = expectedBranchSize
  }
}

public extension Strategy {
  func flatMap<NewValue: Sendable>(
    _ transform: @escaping @Sendable (Value) -> Strategy<NewValue>
  ) -> Strategy<NewValue> {
    let innerDraw = draw
    return Strategy<NewValue>(
      label: "flatMap(\(label))",
      draw: { data in
        let source = try innerDraw(&data)
        return try transform(source).draw(&data)
      },
      shrink: { _ in [] }
    )
  }

  func filter(
    _ predicate: @escaping @Sendable (Value) -> Bool,
    maxAttempts: Int = 32
  ) -> Strategy<Value> {
    let innerDraw = draw
    let innerLabel = label
    return Strategy<Value>(
      label: "filter(\(label))",
      draw: { data in
        for _ in 0..<maxAttempts {
          let candidate = try innerDraw(&data)
          if predicate(candidate) {
            return candidate
          }
        }
        throw StrategyError.filterExhausted(
          label: innerLabel,
          maxAttempts: maxAttempts
        )
      },
      shrink: shrink
    )
  }

  /// Precondition filter: alias for ``filter(_:maxAttempts:)`` with
  /// clearer intent for property-level assumptions.
  ///
  /// Use `assume` when restricting the generated domain, e.g.
  /// `strategy.assume { $0 > 0 }`.  The runner silently skips runs
  /// where the assumption cannot be satisfied within `maxAttempts`.
  func assume(
    _ predicate: @escaping @Sendable (Value) -> Bool,
    maxAttempts: Int = 32
  ) -> Strategy<Value> {
    let innerDraw = draw
    let innerLabel = label
    return Strategy<Value>(
      label: "assume(\(label))",
      draw: { data in
        for _ in 0..<maxAttempts {
          let candidate = try innerDraw(&data)
          if predicate(candidate) {
            return candidate
          }
        }
        throw StrategyError.assumptionFailed(
          label: innerLabel,
          maxAttempts: maxAttempts
        )
      },
      shrink: shrink
    )
  }

  /// Alias for ``assume(_:maxAttempts:)`` using terminology common in
  /// property-testing libraries.
  func suchThat(
    _ predicate: @escaping @Sendable (Value) -> Bool,
    maxAttempts: Int = 32
  ) -> Strategy<Value> {
    assume(predicate, maxAttempts: maxAttempts)
  }

  /// Builds a strategy from a generated size hint in `0...maxSize`.
  static func sized(
    maxSize: Int = 100,
    _ build: @escaping @Sendable (Int) -> Strategy<Value>
  ) -> Strategy<Value> {
    precondition(maxSize >= 0, "sized(maxSize:) requires a non-negative size")
    return Strategy<Value>(
      label: "sized(maxSize: \(maxSize))",
      draw: { data in
        let size = data.drawInteger(in: 0...maxSize)
        return try build(size).draw(&data)
      },
      shrink: { value in
        build(0).shrink(value)
      }
    )
  }

  static func oneOf(_ strategies: [Strategy<Value>]) -> Strategy<Value> {
    precondition(!strategies.isEmpty, "oneOf requires at least one strategy")
    return Strategy<Value>(
      label: "oneOf(\(strategies.map(\.label).joined(separator: ", ")))",
      draw: { data in
        let index = data.drawInteger(in: 0...(strategies.count - 1))
        return try strategies[index].draw(&data)
      },
      shrink: { _ in [] }
    )
  }

  static func frequency(
    _ weightedStrategies: [(Int, Strategy<Value>)]
  ) -> Strategy<Value> {
    let filtered = weightedStrategies.filter { $0.0 > 0 }
    precondition(!filtered.isEmpty, "frequency requires a positive weight")
    let total = filtered.reduce(into: 0) { $0 += $1.0 }
    let labels = filtered.map { "\($0.0):\($0.1.label)" }
      .joined(separator: ", ")
    return Strategy<Value>(
      label: "frequency(\(labels))",
      draw: { data in
        let pick = data.drawInteger(in: 0...(total - 1))
        var cumulative = 0
        for (weight, strategy) in filtered {
          cumulative += weight
          if pick < cumulative {
            return try strategy.draw(&data)
          }
        }
        return try filtered[filtered.count - 1].1.draw(&data)
      },
      shrink: { _ in [] }
    )
  }

  // MARK: - Constant & elements

  /// A strategy that always produces the given value.
  static func constant(_ value: Value) -> Strategy<Value> {
    .just(value)
  }

  /// Chooses uniformly from a non-empty array of fixed values.
  static func elements(of values: [Value]) -> Strategy<Value> {
    precondition(!values.isEmpty, "elements(of:) requires a non-empty array")
    return Strategy<Value>(
      label: "elements(of: \(values.count) values)",
      draw: { data in
        let index = data.drawInteger(in: 0...(values.count - 1))
        return values[index]
      },
      shrink: { value in
        // Shrink toward the first element.
        guard let first = values.first else { return [] }
        let firstDesc = String(describing: first)
        let valueDesc = String(describing: value)
        if firstDesc == valueDesc { return [] }
        return [first]
      }
    )
  }

  /// Generates a random permutation of the given array.
  static func permutations(of values: [Value]) -> Strategy<[Value]> {
    Strategy<[Value]>(
      label: "permutations(of: \(values.count) values)",
      draw: { data in
        var result = values
        // Fisher-Yates shuffle driven by the choice sequence.
        for i in stride(from: result.count - 1, through: 1, by: -1) {
          let j = data.drawInteger(in: 0...i)
          result.swapAt(i, j)
        }
        return result
      },
      shrink: { _ in
        // The identity permutation is the smallest.
        [values]
      }
    )
  }

  static func recursive(
    _ config: RecursiveStrategyConfig,
    leaf: Strategy<Value>,
    _ build: @escaping @Sendable (Strategy<Value>) -> Strategy<Value>
  ) -> Strategy<Value> {
    func make(level: Int) -> Strategy<Value> {
      guard level > 0 else { return leaf }
      let smaller = make(level: level - 1)
      let branch = build(smaller)
      let branchWeight = max(1, config.expectedBranchSize)
      let leafWeight = max(1, config.desiredSize)
      return Strategy<Value>(
        label: "recursive(level:\(level), leaf:\(leaf.label), branch:\(branch.label))",
        draw: { data in
          let pick = data.drawInteger(in: 0...(leafWeight + branchWeight - 1))
          if pick < leafWeight {
            return try leaf.draw(&data)
          }
          return try branch.draw(&data)
        },
        shrink: { _ in [] }
      )
    }

    return make(level: config.depth)
  }

}
