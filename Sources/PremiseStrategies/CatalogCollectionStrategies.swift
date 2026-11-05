import PremiseCore
// MARK: - Fixed dictionaries, records, and unique arrays

public extension Strategy {
  /// Generates a dictionary with a fixed key set and per-key value strategies.
  static func fixedDictionary<Key: Hashable & Sendable, Element: Sendable>(
    _ fields: [Key: Strategy<Element>]
  ) -> Strategy<[Key: Element]> {
    let orderedFields = fields.sorted {
      String(describing: $0.key) < String(describing: $1.key)
    }
    return Strategy<[Key: Element]>(
      label: "fixedDictionary(\(orderedFields.count) fields)",
      draw: { data in
        var result: [Key: Element] = [:]
        for (key, strategy) in orderedFields {
          result[key] = try strategy.draw(&data)
        }
        return result
      },
      shrink: { value in
        shrinkDictionary(value, fields: orderedFields)
      }
    )
  }

  /// Alias for string-keyed fixed dictionaries, useful for record-shaped payloads.
  static func record<Element: Sendable>(
    _ fields: [String: Strategy<Element>]
  ) -> Strategy<[String: Element]> {
    fixedDictionary(fields)
  }

  /// Generates arrays whose elements are unique by value.
  static func uniqueArrays<Element: Hashable & Sendable>(
    of element: Strategy<Element>,
    length: ClosedRange<Int>
  ) -> Strategy<[Element]> {
    arrays(of: element, length: length, uniqueBy: { $0 })
  }

  /// Generates arrays whose elements are unique according to `key`.
  static func arrays<Element: Sendable, Key: Hashable & Sendable>(
    of element: Strategy<Element>,
    length: ClosedRange<Int>,
    uniqueBy key: @escaping @Sendable (Element) -> Key
  ) -> Strategy<[Element]> {
    precondition(length.lowerBound >= 0, "array length must be non-negative")
    return Strategy<[Element]>(
      label: "arrays(of: \(element.label), length: \(length), uniqueBy: key)",
      draw: { data in
        try UniqueArrayDrawer(element: element, key: key)
          .draw(length, using: &data)
      },
      shrink: { value in
        guard !value.isEmpty, value.count > length.lowerBound else { return [] }
        return [Array(value.dropLast())].filter { length.contains($0.count) }
      }
    )
  }
}

// MARK: - Generated functions

public extension Strategy {
  /// Generates deterministic function-like values from sampled input/output cases.
  static func generatedFunctions<Input: Hashable & Sendable, Output: Sendable>(
    inputs: Strategy<Input>,
    outputs: Strategy<Output>,
    tableSize: ClosedRange<Int> = 0...8
  ) -> Strategy<GeneratedFunction<Input, Output>> {
    Strategy<GeneratedFunction<Input, Output>>(
      label: "generatedFunctions(inputs: \(inputs.label), outputs: \(outputs.label))",
      draw: { data in
        let defaultOutput = try outputs.draw(&data)
        let count = drawEdgeBiasedInteger(in: tableSize, using: &data)
        var cases: [Input: Output] = [:]
        let maxAttempts = max(32, count * 16)
        for _ in 0..<maxAttempts where cases.count < count {
          cases[try inputs.draw(&data)] = try outputs.draw(&data)
        }
        return GeneratedFunction(defaultOutput: defaultOutput, cases: cases)
      },
      shrink: { _ in [] }
    )
  }
}
// MARK: - Range, slice, and index strategies

public extension Strategy where Value == Int {
  /// Generates valid indices in `bounds`.
  static func indices(in bounds: Range<Int>) -> Strategy<Int> {
    precondition(!bounds.isEmpty, "indices(in:) requires a non-empty range")
    return .integers(in: bounds.lowerBound...(bounds.upperBound - 1))
  }
}

public extension Strategy where Value == Range<Int> {
  /// Generates half-open integer ranges contained in `bounds`.
  static func ranges(in bounds: Range<Int>) -> Strategy<Range<Int>> {
    precondition(
      bounds.lowerBound <= bounds.upperBound,
      "ranges(in:) requires ordered bounds"
    )
    return Strategy<Range<Int>>(
      label: "ranges(in: \(bounds))",
      draw: { data in
        let start = data.drawInteger(in: bounds.lowerBound...bounds.upperBound)
        let end = data.drawInteger(in: start...bounds.upperBound)
        return start..<end
      },
      shrink: { value in
        value.isEmpty && value.lowerBound == bounds.lowerBound
          ? [] : [bounds.lowerBound..<bounds.lowerBound]
      }
    )
  }
}

public extension Strategy where Value == ClosedRange<Int> {
  /// Generates closed integer ranges contained in `bounds`.
  static func closedRanges(
    in bounds: ClosedRange<Int>
  ) -> Strategy<ClosedRange<Int>> {
    Strategy<ClosedRange<Int>>(
      label: "closedRanges(in: \(bounds))",
      draw: { data in
        let start = data.drawInteger(in: bounds)
        let end = data.drawInteger(in: start...bounds.upperBound)
        return start...end
      },
      shrink: { value in
        value == bounds.lowerBound...bounds.lowerBound
          ? [] : [bounds.lowerBound...bounds.lowerBound]
      }
    )
  }
}

private struct UniqueArrayDrawer<Element: Sendable, Key: Hashable & Sendable> {
  let element: Strategy<Element>
  let key: @Sendable (Element) -> Key

  func draw(
    _ length: ClosedRange<Int>,
    using data: inout PremiseData
  ) throws -> [Element] {
    let count = drawEdgeBiasedInteger(in: length, using: &data)
    var values: [Element] = []
    var seen: Set<Key> = []
    let maxAttempts = max(32, count * 16)
    for _ in 0..<maxAttempts where values.count < count {
      let candidate = try element.draw(&data)
      if seen.insert(key(candidate)).inserted {
        values.append(candidate)
      }
    }
    guard values.count == count else {
      throw StrategyError.filterExhausted(
        label: "unique array elements for \(element.label)",
        maxAttempts: maxAttempts
      )
    }
    return values
  }
}

private func shrinkDictionary<Key: Hashable, Element: Sendable>(
  _ value: [Key: Element],
  fields: [(key: Key, value: Strategy<Element>)]
) -> [[Key: Element]] {
  fields.compactMap { key, strategy in
    guard let current = value[key],
      let shrunk = strategy.shrink(current).first
    else { return nil }
    var copy = value
    copy[key] = shrunk
    return copy
  }
}
