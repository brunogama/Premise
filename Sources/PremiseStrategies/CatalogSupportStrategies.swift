import PremiseCore
/// A deterministic generated function backed by a finite input/output table.
public struct GeneratedFunction<Input: Hashable & Sendable, Output: Sendable>:
  Sendable
{
  /// Output returned for inputs that are absent from ``cases``.
  public let defaultOutput: Output

  /// Explicit input/output cases for this generated function.
  public let cases: [Input: Output]

  /// Creates a generated function from a default output and explicit cases.
  public init(defaultOutput: Output, cases: [Input: Output]) {
    self.defaultOutput = defaultOutput
    self.cases = cases
  }

  /// Returns the mapped output for `input`, or ``defaultOutput`` if absent.
  public func callAsFunction(_ input: Input) -> Output {
    cases[input] ?? defaultOutput
  }
}

// MARK: - Sampled values and enums

public extension Strategy {
  /// Chooses uniformly from a non-empty collection of fixed values.
  static func sampled<Values: Collection>(
    from values: Values
  ) -> Strategy<Value>
  where Values.Element == Value {
    elements(of: Array(values))
  }

  /// Lazily resolves a strategy at draw time, supporting mutually-recursive definitions.
  static func deferred(
    label: String = "deferred",
    _ makeStrategy: @escaping @Sendable () -> Strategy<Value>
  ) -> Strategy<Value> {
    Strategy<Value>(
      label: label,
      draw: { data in try makeStrategy().draw(&data) },
      shrink: { value in makeStrategy().shrink(value) }
    )
  }

  /// Builds a custom strategy with direct access to `PremiseData`.
  static func composite(
    label: String = "composite",
    _ draw: @escaping @Sendable (inout PremiseData) throws -> Value,
    shrink: @escaping @Sendable (Value) -> [Value] = { _ in [] }
  ) -> Strategy<Value> {
    Strategy<Value>(label: label, draw: draw, shrink: shrink)
  }

  /// Draws one shared value and exposes it as a `just` strategy to a sub-strategy.
  ///
  /// This models Hypothesis-style shared values within a single generated example:
  /// every draw from the provided nested strategy sees the same value.
  static func shared<SharedValue: Sendable>(
    _ source: Strategy<SharedValue>,
    label: String = "shared",
    _ build: @escaping @Sendable (Strategy<SharedValue>) -> Strategy<Value>
  ) -> Strategy<Value> {
    Strategy<Value>(
      label: "\(label)(\(source.label))",
      draw: { data in
        let sharedValue = try source.draw(&data)
        return try build(.just(sharedValue)).draw(&data)
      },
      shrink: { _ in [] }
    )
  }
}


public extension Strategy
where
  Value: CaseIterable,
  Value.AllCases: Collection,
  Value.AllCases.Element == Value
{
  /// Chooses from all cases of a `CaseIterable` value.
  static var cases: Strategy<Value> {
    elements(of: Array(Value.allCases))
  }
}
