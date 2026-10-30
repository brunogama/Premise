import PremiseCore
func drawEdgeBiasedCount(
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

func drawUniqueDictionaryPairs<Key: Hashable & Sendable, Value: Sendable>(
  count: Int,
  strategies: (keys: Strategy<Key>, values: Strategy<Value>),
  data: inout PremiseData
) throws -> [(Key, Value)] {
  guard count > 0 else { return [] }

  var pairs: [(Key, Value)] = []
  var seenKeys: Set<Key> = []
  let maxAttempts = uniqueAttemptLimit(for: count)

  for _ in 0..<maxAttempts where pairs.count < count {
    if let pair = try drawDictionaryPair(
      strategies,
      seenKeys: &seenKeys,
      data: &data
    ) {
      pairs.append(pair)
    }
  }

  guard pairs.count == count else {
    throw StrategyError.filterExhausted(
      label: "unique dictionary keys for \(strategies.keys.label)",
      maxAttempts: maxAttempts
    )
  }
  return pairs
}

private func drawDictionaryPair<Key: Hashable & Sendable, Value: Sendable>(
  _ strategies: (keys: Strategy<Key>, values: Strategy<Value>),
  seenKeys: inout Set<Key>,
  data: inout PremiseData
) throws -> (Key, Value)? {
  try data.withSpan { spanData in
    let key = try strategies.keys.draw(&spanData)
    guard seenKeys.insert(key).inserted else { return nil }
    return (key, try strategies.values.draw(&spanData))
  }
}
func drawUniqueSetValues<Element: Hashable & Sendable>(
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
