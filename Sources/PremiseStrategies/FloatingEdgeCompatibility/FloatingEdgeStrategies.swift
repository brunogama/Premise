import PremiseCore

public extension Strategy where Value == Double {
  // Keep the published floating-point options source-compatible.
  // swiftlint:disable function_parameter_count
  /// Edge-biased `Double` generation with opt-in exceptional values.
  ///
  /// Finite edge candidates are constrained to `range`. When enabled,
  /// `NaN` and infinities are yielded independently of `range` because
  /// `NaN` is not contained by any Swift range and infinities exercise
  /// exceptional floating-point behavior outside finite bounds.
  static func edgeCaseFloats(
    in range: ClosedRange<Double>,
    includeNaN: Bool = false,
    includeInfinity: Bool = false,
    includeDenormals: Bool = false,
    epsilonAround pivot: Double? = nil
  ) -> Strategy<Double> {
    // swiftlint:enable function_parameter_count
    let options = FloatingEdgeOptions(
      includeNaN: includeNaN,
      includeInfinity: includeInfinity,
      includeDenormals: includeDenormals,
      pivot: pivot
    )
    return makeFloatingEdgeStrategy(in: range, options: options)
  }
}
