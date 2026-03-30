import PremiseCore

public struct RecursiveStrategyConfig: Sendable {
  public var depth: Int
  public var desiredSize: Int
  public var expectedBranchSize: Int

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

  /// Precondition filter — alias for ``filter(_:maxAttempts:)`` with
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

  static func frequency(_ weightedStrategies: [(Int, Strategy<Value>)]) -> Strategy<Value> {
    let filtered = weightedStrategies.filter { $0.0 > 0 }
    precondition(!filtered.isEmpty, "frequency requires a positive weight")
    let total = filtered.reduce(into: 0) { $0 += $1.0 }
    return Strategy<Value>(
      label: "frequency(\(filtered.map { "\($0.0):\($0.1.label)" }.joined(separator: ", ")))",
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

// MARK: - Zip (parameter packs, free function)

/// Combines an arbitrary number of strategies into a tuple using Swift
/// parameter packs.  Each component is drawn independently and shrinking
/// delegates to trace-based ``ShrinkMachine`` (value-level shrinking is
/// not feasible across heterogeneous packs).
///
/// ```swift
/// let pair = zip(.integers(in: 0...10), Strategy<String>.ascii)
/// let triple = zip(.integers(in: 0...10), Strategy<Bool>.booleans, Strategy<String>.ascii)
/// ```
public func zip<each T: Sendable>(
  _ strategy: repeat Strategy<each T>
) -> Strategy<(repeat each T)> {
  let labels = packLabels(repeat each strategy)
  return Strategy<(repeat each T)>(
    label: "zip(\(labels))",
    draw: { data in
      (repeat try (each strategy).draw(&data))
    },
    // Value-level shrinking across parameter packs is not expressible;
    // trace-based ShrinkMachine handles minimisation.
    shrink: { _ in [] }
  )
}

// MARK: - Pack helpers

/// Collects strategy labels from a parameter pack into a comma-separated
/// string for diagnostics.
private func packLabels<each T: Sendable>(
  _ strategy: repeat Strategy<each T>
) -> String {
  var labels: [String] = []
  func append<S: Sendable>(_ s: Strategy<S>) { labels.append(s.label) }
  repeat append(each strategy)
  return labels.joined(separator: ", ")
}
