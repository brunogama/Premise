import PremiseCore

public extension Strategy {
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
        guard !value.isEmpty else { return [] }
        return [Array(value.dropLast()), []].filter { length.contains($0.count) }
      }
    )
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
        guard !value.isEmpty else { return [] }
        let candidate = Dictionary(uniqueKeysWithValues: value.dropLast())
        return [candidate].filter { count.contains($0.count) }
      }
    )
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
        guard !value.isEmpty else { return [] }
        return [Set(value.dropLast())].filter { count.contains($0.count) }
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
