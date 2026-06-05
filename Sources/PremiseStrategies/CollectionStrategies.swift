import PremiseCore

public extension Strategy {
  /// Generates arrays with exactly `count` elements.
  static func arrays(
    of element: Strategy<Value>,
    count: Int
  ) -> Strategy<[Value]> {
    arrays(of: element, length: count...count)
  }

  /// Generates arrays whose size is in `minCount...maxCount`.
  static func arrays(
    of element: Strategy<Value>,
    minCount: Int,
    maxCount: Int
  ) -> Strategy<[Value]> {
    arrays(of: element, length: minCount...maxCount)
  }

  /// Generates arrays whose size is selected from `length`.
  static func arrays(
    of element: Strategy<Value>,
    length: ClosedRange<Int>
  ) -> Strategy<[Value]> {
    precondition(length.lowerBound >= 0, "array length must be non-negative")
    return Strategy<[Value]>(
      label: "arrays(of: \(element.label), length: \(length))",
      draw: { data in
        let count = drawEdgeBiasedCount(in: length, using: &data)
        var values: [Value] = []
        values.reserveCapacity(count)
        for _ in 0..<count {
          let value = try data.withSpan { spanData in
            try element.draw(&spanData)
          }
          values.append(value)
        }
        return values
      },
      shrink: { value in
        shrinkArray(value, element: element, length: length)
      }
    )
  }

  /// Generates dictionaries with exactly `count` unique keys.
  static func dictionaries<Key: Hashable & Sendable, Element: Sendable>(
    keys: Strategy<Key>,
    values: Strategy<Element>,
    count: Int
  ) -> Strategy<[Key: Element]> {
    dictionaries(keys: keys, values: values, count: count...count)
  }

  /// Generates dictionaries whose number of unique keys is in `minCount...maxCount`.
  static func dictionaries<Key: Hashable & Sendable, Element: Sendable>(
    keys: Strategy<Key>,
    values: Strategy<Element>,
    minCount: Int,
    maxCount: Int
  ) -> Strategy<[Key: Element]> {
    dictionaries(keys: keys, values: values, count: minCount...maxCount)
  }

  /// Generates dictionaries whose number of unique keys is selected from `count`.
  static func dictionaries<Key: Hashable & Sendable, Element: Sendable>(
    keys: Strategy<Key>,
    values: Strategy<Element>,
    count: ClosedRange<Int>
  ) -> Strategy<[Key: Element]> {
    precondition(count.lowerBound >= 0, "dictionary count must be non-negative")
    return Strategy<[Key: Element]>(
      label: "dictionaries(keys: \(keys.label), values: \(values.label), count: \(count))",
      draw: { data in
        let pairCount = drawEdgeBiasedCount(in: count, using: &data)
        let pairs = try drawUniqueDictionaryPairs(
          count: pairCount,
          keys: keys,
          values: values,
          data: &data
        )
        let sorted = pairs.enumerated().sorted { lhs, rhs in
          let left = String(describing: lhs.element.0)
          let right = String(describing: rhs.element.0)
          return left == right ? lhs.offset < rhs.offset : left < right
        }
        return Dictionary(sorted.map(\.element), uniquingKeysWith: { _, new in new })
      },
      shrink: { value in
        shrinkDictionary(value, keys: keys, values: values, count: count)
      }
    )
  }

  /// Generates sets with exactly `count` unique elements.
  static func sets<Element: Hashable & Sendable>(
    of element: Strategy<Element>,
    count: Int
  ) -> Strategy<Set<Element>> {
    sets(of: element, count: count...count)
  }

  /// Generates sets whose size is in `minCount...maxCount`.
  static func sets<Element: Hashable & Sendable>(
    of element: Strategy<Element>,
    minCount: Int,
    maxCount: Int
  ) -> Strategy<Set<Element>> {
    sets(of: element, count: minCount...maxCount)
  }

  /// Generates sets whose size is selected from `count`.
  static func sets<Element: Hashable & Sendable>(
    of element: Strategy<Element>,
    count: ClosedRange<Int>
  ) -> Strategy<Set<Element>> {
    precondition(count.lowerBound >= 0, "set count must be non-negative")
    return Strategy<Set<Element>>(
      label: "sets(of: \(element.label), count: \(count))",
      draw: { data in
        let itemCount = drawEdgeBiasedCount(in: count, using: &data)
        let values = try drawUniqueSetValues(
          count: itemCount,
          element: element,
          data: &data
        )
        let ordered = values.sorted { String(describing: $0) < String(describing: $1) }
        return Set(ordered)
      },
      shrink: { value in
        shrinkSet(value, element: element, count: count)
      }
    )
  }
}

private func drawEdgeBiasedCount(
  in range: ClosedRange<Int>,
  using data: inout PremiseData
) -> Int {
  let chooser = data.drawInteger(in: 0...4)
  if chooser == 0 {
    return range.lowerBound
  }

  if chooser == 1 {
    return range.upperBound
  }

  if chooser == 2, range.contains(0) {
    return 0
  }

  return data.drawInteger(in: range)
}

private func drawUniqueDictionaryPairs<Key: Hashable & Sendable, Value: Sendable>(
  count: Int,
  keys: Strategy<Key>,
  values: Strategy<Value>,
  data: inout PremiseData
) throws -> [(Key, Value)] {
  guard count > 0 else { return [] }

  var pairs: [(Key, Value)] = []
  var seenKeys: Set<Key> = []
  let maxAttempts = uniqueAttemptLimit(for: count)

  for _ in 0..<maxAttempts where pairs.count < count {
    let pair = try data.withSpan { spanData -> (Key, Value)? in
      let key = try keys.draw(&spanData)
      guard seenKeys.insert(key).inserted else {
        return nil
      }
      let value = try values.draw(&spanData)
      return (key, value)
    }
    if let pair {
      pairs.append(pair)
    }
  }

  guard pairs.count == count else {
    throw StrategyError.filterExhausted(
      label: "unique dictionary keys for \(keys.label)",
      maxAttempts: maxAttempts
    )
  }
  return pairs
}

private func drawUniqueSetValues<Element: Hashable & Sendable>(
  count: Int,
  element: Strategy<Element>,
  data: inout PremiseData
) throws -> [Element] {
  guard count > 0 else { return [] }

  var values: [Element] = []
  var seenValues: Set<Element> = []
  let maxAttempts = uniqueAttemptLimit(for: count)

  for _ in 0..<maxAttempts where values.count < count {
    let value = try data.withSpan { spanData in
      try element.draw(&spanData)
    }
    if seenValues.insert(value).inserted {
      values.append(value)
    }
  }

  guard values.count == count else {
    throw StrategyError.filterExhausted(
      label: "unique set elements for \(element.label)",
      maxAttempts: maxAttempts
    )
  }
  return values
}

private func uniqueAttemptLimit(for count: Int) -> Int {
  max(32, count * 16)
}

private func shrinkArray<Value: Sendable>(
  _ value: [Value],
  element: Strategy<Value>,
  length: ClosedRange<Int>
) -> [[Value]] {
  guard !value.isEmpty else { return [] }
  var candidates: [[Value]] = []
  let minimum = length.lowerBound
  if value.count > minimum {
    candidates.append(Array(value.dropLast()))
    candidates.append(Array(value.dropFirst()))
    candidates.append(Array(value.prefix(minimum)))
  }
  for index in value.indices {
    for shrunk in element.shrink(value[index]) {
      var copy = value
      copy[index] = shrunk
      candidates.append(copy)
    }
  }
  return uniqueArrays(candidates.filter { length.contains($0.count) })
}

private func shrinkDictionary<Key: Hashable & Sendable, Value: Sendable>(
  _ value: [Key: Value],
  keys: Strategy<Key>,
  values: Strategy<Value>,
  count: ClosedRange<Int>
) -> [[Key: Value]] {
  guard !value.isEmpty else { return [] }
  let pairs = value.sorted { String(describing: $0.key) < String(describing: $1.key) }
  var candidates: [[Key: Value]] = []
  if value.count > count.lowerBound {
    candidates.append(Dictionary(uniqueKeysWithValues: pairs.dropLast()))
  }
  for (key, elementValue) in pairs {
    for shrunkValue in values.shrink(elementValue) {
      var copy = value
      copy[key] = shrunkValue
      candidates.append(copy)
    }
    for shrunkKey in keys.shrink(key) where shrunkKey != key {
      var copy = value
      copy.removeValue(forKey: key)
      copy[shrunkKey] = elementValue
      candidates.append(copy)
    }
  }
  return uniqueDictionaries(candidates.filter { count.contains($0.count) })
}

private func shrinkSet<Element: Hashable & Sendable>(
  _ value: Set<Element>,
  element: Strategy<Element>,
  count: ClosedRange<Int>
) -> [Set<Element>] {
  guard !value.isEmpty else { return [] }
  let ordered = value.sorted { String(describing: $0) < String(describing: $1) }
  var candidates: [Set<Element>] = []
  if value.count > count.lowerBound {
    candidates.append(Set(ordered.dropLast()))
  }
  for item in ordered {
    for shrunk in element.shrink(item) where shrunk != item {
      var copy = value
      copy.remove(item)
      copy.insert(shrunk)
      candidates.append(copy)
    }
  }
  return uniqueSets(candidates.filter { count.contains($0.count) })
}

private func uniqueArrays<Value>(_ values: [[Value]]) -> [[Value]] {
  var seen: Set<String> = []
  return values.filter { value in
    seen.insert(String(describing: value)).inserted
  }
}

private func uniqueDictionaries<Key, Value>(_ values: [[Key: Value]]) -> [[Key: Value]] {
  var seen: Set<String> = []
  return values.filter { value in
    seen.insert(String(describing: value)).inserted
  }
}

private func uniqueSets<Element>(_ values: [Set<Element>]) -> [Set<Element>] {
  var seen: Set<String> = []
  return values.filter { value in
    seen.insert(String(describing: value)).inserted
  }
}
