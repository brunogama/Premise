/// Witness-backed generation contract for property strategies.
///
/// A `Strategy` is a pair of closures — one to generate (`draw`) and one to
/// minimise (`shrink`).  Strategies compose via `map`, `flatMap`, `filter`,
/// `zip`, and other combinators in `PremiseStrategies`.
///
/// ```swift
/// let evens = Strategy<Int>.integers(in: 0...100).filter { $0.isMultiple(of: 2) }
/// ```
public struct Strategy<Value: Sendable>: Sendable {
  public let label: String
  public let draw: @Sendable (inout PremiseData) throws -> Value
  public let shrink: @Sendable (Value) -> [Value]

  public init(
    label: String,
    draw: @escaping @Sendable (inout PremiseData) throws -> Value,
    shrink: @escaping @Sendable (Value) -> [Value] = { _ in [] }
  ) {
    self.label = label
    self.draw = draw
    self.shrink = shrink
  }
}

// MARK: - CustomStringConvertible

extension Strategy: CustomStringConvertible {
  public var description: String {
    "Strategy<\(Value.self)>(\(label))"
  }
}

// MARK: - Core combinators

public extension Strategy {
  static func just(_ value: Value) -> Strategy<Value> {
    Strategy(label: "just(\(String(describing: value)))", draw: { _ in value }, shrink: { _ in [] })
  }

  /// A strategy that never produces examples.
  ///
  /// Use `nothing()` as a placeholder in conditional strategy construction or
  /// to model impossible branches. Drawing from it throws during generation,
  /// so the runner rejects that attempt instead of reporting a property failure.
  static func nothing(label: String = "nothing") -> Strategy<Value> {
    Strategy<Value>(
      label: label,
      draw: { _ in throw StrategyError.noExamples(label: label) },
      shrink: { _ in [] }
    )
  }

  func map<NewValue: Sendable>(
    _ transform: @escaping @Sendable (Value) -> NewValue
  ) -> Strategy<NewValue> {
    let innerDraw = draw
    return Strategy<NewValue>(
      label: "map(\(label))",
      draw: { data in
        try transform(innerDraw(&data))
      },
      shrink: { _ in [] }
    )
  }

  /// Returns a copy of this strategy with a replacement value-level shrinker.
  func shrinking(
    _ shrinker: @escaping @Sendable (Value) -> [Value]
  ) -> Strategy<Value> {
    Strategy<Value>(
      label: label,
      draw: draw,
      shrink: shrinker
    )
  }
}

// MARK: - Debug & inspection

public extension Strategy {
  /// Draws `count` sample values using pseudo-random generation.
  ///
  /// Useful for interactive exploration in a playground or debugger:
  ///
  /// ```swift
  /// let samples = Strategy<Int>.integers(in: 0...100).sample(count: 5)
  /// // e.g. [42, 0, 100, 73, 17]
  /// ```
  ///
  /// - Parameters:
  ///   - count: Number of samples to generate.
  ///   - seed: Base seed for reproducibility.  Defaults to a random seed.
  /// - Returns: An array of drawn values, skipping any that fail to draw.
  func sample(count: Int = 10, seed: UInt64? = nil) -> [Value] {
    let baseSeed = seed ?? UInt64.random(in: .min ... .max)
    var results: [Value] = []
    results.reserveCapacity(count)
    for i in 0..<count {
      let provider = PseudoRandomProvider(
        seed: baseSeed &+ UInt64(i),
        maxDraws: 10_000
      )
      var data = PremiseData(provider: provider)
      if let value = try? draw(&data) {
        results.append(value)
      }
    }
    return results
  }

  /// Draws a single sample value.
  ///
  /// - Parameter seed: Seed for reproducibility.
  /// - Returns: A drawn value, or `nil` if generation fails.
  func sampleOne(seed: UInt64? = nil) -> Value? {
    sample(count: 1, seed: seed).first
  }
}
