import PremiseCore

/// Sparse vector value used by built-in vector-ish strategies.
public struct SparseVector: Sendable, Equatable, Codable {
  public var dimensions: Int
  public var entries: [Int: Double]

  public init(dimensions: Int, entries: [Int: Double]) {
    self.dimensions = dimensions
    self.entries = entries
  }
}

/// Quantized numeric value with a raw integer bucket and floating scale.
public struct QuantizedValue: Sendable, Equatable, Codable {
  public var raw: Int
  public var scale: Double

  public init(raw: Int, scale: Double) {
    self.raw = raw
    self.scale = scale
  }

  public var value: Double {
    Double(raw) * scale
  }
}

/// Generic index workflow operation for model-based index tests.
public struct IndexOperation: Sendable, Equatable, Codable {
  public enum Kind: String, Sendable, Codable {
    case insert
    case update
    case delete
    case query
  }

  public var kind: Kind
  public var index: Int
  public var value: Int?

  public init(kind: Kind, index: Int, value: Int? = nil) {
    self.kind = kind
    self.index = index
    self.value = value
  }
}

public extension Strategy where Value == Int {
  /// Generates vector dimensions with a bias toward the lower bound.
  static func dimensions(in range: ClosedRange<Int>) -> Strategy<Int> {
    integers(in: range).shrinking { value in
      guard value != range.lowerBound else { return [] }
      return [range.lowerBound, max(range.lowerBound, value / 2)]
        .filter { range.contains($0) && $0 != value }
    }
  }
}

public extension Strategy where Value == [Double] {
  /// Generates a dense vector with an exact dimension count.
  static func denseVector(
    dimensions: Int,
    elements: Strategy<Double> = .finite
  ) -> Strategy<[Double]> {
    Strategy<Double>.arrays(of: elements, count: dimensions)
      .shrinking { vector in
        shrinkDenseVector(vector, elements: elements)
      }
  }
}

public extension Strategy where Value == SparseVector {
  /// Generates a sparse vector with bounded non-zero entries.
  static func sparseVector(
    dimensions: Int,
    nonZeroCount: ClosedRange<Int>,
    values: Strategy<Double> = .finite
  ) -> Strategy<SparseVector> {
    let indexStrategy = Strategy<Int>.integers(in: 0...max(0, dimensions - 1))
    return Strategy<SparseVector>(
      label: "sparseVector(dimensions: \(dimensions), nonZeroCount: \(nonZeroCount))",
      draw: { data in
        let count = data.drawInteger(in: nonZeroCount)
        var entries: [Int: Double] = [:]
        for _ in 0..<count {
          let index = try indexStrategy.draw(&data)
          entries[index] = try values.draw(&data)
        }
        return SparseVector(dimensions: dimensions, entries: entries)
      },
      shrink: { vector in
        shrinkSparseVector(vector, values: values)
      }
    )
  }
}

public extension Strategy where Value == QuantizedValue {
  /// Generates quantized values from an integer bucket range and scale.
  static func quantizedValues(
    raw range: ClosedRange<Int>,
    scale: Double
  ) -> Strategy<QuantizedValue> {
    Strategy<Int>.integers(in: range).map { raw in
      QuantizedValue(raw: raw, scale: scale)
    }
    .shrinking { value in
      Strategy<Int>.integers(in: range).shrink(value.raw).map {
        QuantizedValue(raw: $0, scale: scale)
      }
    }
  }
}

public extension Strategy where Value == IndexOperation {
  /// Generates generic index operations for database and index workflows.
  static func indexOperations(
    indexRange: ClosedRange<Int>,
    value: ClosedRange<Int>
  ) -> Strategy<IndexOperation> {
    let kinds: [IndexOperation.Kind] = [.insert, .update, .delete, .query]
    return Strategy<IndexOperation>(
      label: "indexOperations(indexRange: \(indexRange), value: \(value))",
      draw: { data in
        let kind = kinds[data.drawInteger(in: 0...(kinds.count - 1))]
        let index = data.drawInteger(in: indexRange)
        let payload = kind == .delete || kind == .query ? nil : data.drawInteger(in: value)
        return IndexOperation(kind: kind, index: index, value: payload)
      },
      shrink: { operation in
        shrinkIndexOperation(operation, indexRange: indexRange, valueRange: value)
      }
    )
  }
}

public extension Strategy where Value == [IndexOperation] {
  /// Generates shrinkable sequences of index operations.
  static func indexOperationSequences(
    length: ClosedRange<Int>,
    indexRange: ClosedRange<Int>,
    value: ClosedRange<Int>
  ) -> Strategy<[IndexOperation]> {
    Strategy<IndexOperation>.arrays(
      of: Strategy<IndexOperation>.indexOperations(indexRange: indexRange, value: value),
      length: length
    )
  }
}

private func shrinkDenseVector(
  _ vector: [Double],
  elements: Strategy<Double>
) -> [[Double]] {
  guard !vector.isEmpty else { return [] }
  var candidates: [[Double]] = []
  candidates.append(Array(repeating: 0.0, count: vector.count))
  for index in vector.indices {
    for shrunk in elements.shrink(vector[index]) {
      var copy = vector
      copy[index] = shrunk
      candidates.append(copy)
    }
  }
  return candidates
}

private func shrinkSparseVector(
  _ vector: SparseVector,
  values: Strategy<Double>
) -> [SparseVector] {
  guard !vector.entries.isEmpty else { return [] }
  var candidates: [SparseVector] = []
  let orderedKeys = vector.entries.keys.sorted()
  var removed = vector.entries
  removed.removeValue(forKey: orderedKeys.last!)
  candidates.append(SparseVector(dimensions: vector.dimensions, entries: removed))

  for key in orderedKeys {
    guard let value = vector.entries[key] else { continue }
    for shrunk in values.shrink(value) {
      var entries = vector.entries
      entries[key] = shrunk
      candidates.append(SparseVector(dimensions: vector.dimensions, entries: entries))
    }
  }
  return candidates
}

private func shrinkIndexOperation(
  _ operation: IndexOperation,
  indexRange: ClosedRange<Int>,
  valueRange: ClosedRange<Int>
) -> [IndexOperation] {
  var candidates: [IndexOperation] = []
  if operation.kind != .query {
    candidates.append(IndexOperation(kind: .query, index: operation.index))
  }
  if operation.index != indexRange.lowerBound {
    candidates.append(
      IndexOperation(
        kind: operation.kind,
        index: indexRange.lowerBound,
        value: operation.value
      )
    )
  }
  if let value = operation.value, value != valueRange.lowerBound {
    candidates.append(
      IndexOperation(
        kind: operation.kind,
        index: operation.index,
        value: valueRange.lowerBound
      )
    )
  }
  return candidates
}
