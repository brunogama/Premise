import PremiseCore

public extension Strategy {
  static func arrays(
    of element: Strategy<Value>,
    count: Int
  ) -> Strategy<[Value]> {
    arrays(of: element, length: count...count)
  }

  static func arrays(
    of element: Strategy<Value>,
    minCount: Int,
    maxCount: Int
  ) -> Strategy<[Value]> {
    arrays(of: element, length: minCount...maxCount)
  }

  static func arrays(
    of element: Strategy<Value>,
    length: ClosedRange<Int>
  ) -> Strategy<[Value]> {
    Strategy<[Value]>(
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

  static func dictionaries<Key: Hashable & Sendable, Element: Sendable>(
    keys: Strategy<Key>,
    values: Strategy<Element>,
    count: Int
  ) -> Strategy<[Key: Element]> {
    dictionaries(keys: keys, values: values, count: count...count)
  }

  static func dictionaries<Key: Hashable & Sendable, Element: Sendable>(
    keys: Strategy<Key>,
    values: Strategy<Element>,
    minCount: Int,
    maxCount: Int
  ) -> Strategy<[Key: Element]> {
    dictionaries(keys: keys, values: values, count: minCount...maxCount)
  }

  static func dictionaries<Key: Hashable & Sendable, Element: Sendable>(
    keys: Strategy<Key>,
    values: Strategy<Element>,
    count: ClosedRange<Int>
  ) -> Strategy<[Key: Element]> {
    Strategy<[Key: Element]>(
      label: "dictionaries(keys: \(keys.label), values: \(values.label), count: \(count))",
      draw: { data in
        let pairCount = drawEdgeBiasedCount(in: count, using: &data)
        var pairs: [(Key, Element)] = []
        pairs.reserveCapacity(pairCount)
        for _ in 0..<pairCount {
          let pair = try data.withSpan { spanData -> (Key, Element) in
            let key = try keys.draw(&spanData)
            let value = try values.draw(&spanData)
            return (key, value)
          }
          pairs.append(pair)
        }
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

  static func sets<Element: Hashable & Sendable>(
    of element: Strategy<Element>,
    count: Int
  ) -> Strategy<Set<Element>> {
    sets(of: element, count: count...count)
  }

  static func sets<Element: Hashable & Sendable>(
    of element: Strategy<Element>,
    minCount: Int,
    maxCount: Int
  ) -> Strategy<Set<Element>> {
    sets(of: element, count: minCount...maxCount)
  }

  static func sets<Element: Hashable & Sendable>(
    of element: Strategy<Element>,
    count: ClosedRange<Int>
  ) -> Strategy<Set<Element>> {
    Strategy<Set<Element>>(
      label: "sets(of: \(element.label), count: \(count))",
      draw: { data in
        let itemCount = drawEdgeBiasedCount(in: count, using: &data)
        var values: [Element] = []
        values.reserveCapacity(itemCount)
        for _ in 0..<itemCount {
          let value = try data.withSpan { spanData in
            try element.draw(&spanData)
          }
          values.append(value)
        }
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
