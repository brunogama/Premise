import PremiseCore

public extension Strategy {
  // Keep the published min/max overload source-compatible.
  // swiftlint:disable function_parameter_count
  /// Generates dictionaries whose number of unique keys is in `minCount...maxCount`.
  static func dictionaries<Key: Hashable & Sendable, Element: Sendable>(
    keys: Strategy<Key>,
    values: Strategy<Element>,
    minCount: Int,
    maxCount: Int
  ) -> Strategy<[Key: Element]> {
    // swiftlint:enable function_parameter_count
    dictionaries(keys: keys, values: values, count: minCount...maxCount)
  }
}
