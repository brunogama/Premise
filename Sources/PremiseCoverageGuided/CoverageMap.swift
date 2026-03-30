import PremiseCore

/// A thread-safe coverage map that tracks which code edges have been observed.
///
/// Coverage maps aggregate binary edge-hit information. Each edge is identified
/// by an integer index. The map tracks whether an edge has ever been seen,
/// enabling coverage-guided exploration to prioritize inputs that discover
/// new edges.
public struct CoverageMap: Sendable, Equatable {
  /// The raw edge-hit bitmap. Each bit position corresponds to an edge index.
  private var bitmap: [UInt8]

  /// The number of edge slots available in this map.
  public let capacity: Int

  /// The number of distinct edges observed so far.
  public var observedEdgeCount: Int {
    bitmap.reduce(0) { total, byte in
      total + byte.nonzeroBitCount
    }
  }

  /// Creates a coverage map with the given capacity (in edge slots).
  ///
  /// - Parameter capacity: The maximum number of edges to track. Rounded up
  ///   to the nearest multiple of 8.
  public init(capacity: Int = 1024) {
    let byteCount = max(1, (capacity + 7) / 8)
    self.capacity = byteCount * 8
    self.bitmap = [UInt8](repeating: 0, count: byteCount)
  }

  /// Records a hit on the given edge index.
  ///
  /// - Parameter edgeIndex: The edge identifier. Values exceeding `capacity`
  ///   are silently ignored.
  public mutating func recordEdge(_ edgeIndex: Int) {
    guard edgeIndex >= 0, edgeIndex < capacity else { return }
    let byteIndex = edgeIndex / 8
    let bitIndex = UInt8(1 << (edgeIndex % 8))
    bitmap[byteIndex] |= bitIndex
  }

  /// Returns whether the given edge has been observed.
  ///
  /// - Parameter edgeIndex: The edge identifier.
  /// - Returns: `true` if the edge was previously recorded.
  public func hasEdge(_ edgeIndex: Int) -> Bool {
    guard edgeIndex >= 0, edgeIndex < capacity else { return false }
    let byteIndex = edgeIndex / 8
    let bitIndex = UInt8(1 << (edgeIndex % 8))
    return (bitmap[byteIndex] & bitIndex) != 0
  }

  /// Returns the set of edge indices that are present in `other` but not
  /// in `self`.
  ///
  /// - Parameter other: The coverage map to diff against.
  /// - Returns: Edge indices discovered by `other` that `self` has not seen.
  public func newEdges(comparedTo other: Self) -> [Int] {
    let minBytes = min(bitmap.count, other.bitmap.count)
    var result: [Int] = []
    for byteIndex in 0..<minBytes {
      let novel = other.bitmap[byteIndex] & ~bitmap[byteIndex]
      guard novel != 0 else { continue }
      for bit in 0..<8 where novel & (1 << bit) != 0 {
        result.append(byteIndex * 8 + bit)
      }
    }
    // Edges in other beyond our capacity are all novel.
    for byteIndex in minBytes..<other.bitmap.count {
      let byte = other.bitmap[byteIndex]
      guard byte != 0 else { continue }
      for bit in 0..<8 where byte & (1 << bit) != 0 {
        result.append(byteIndex * 8 + bit)
      }
    }
    return result
  }

  /// Merges another coverage map into this one, recording the union of
  /// observed edges.
  ///
  /// - Parameter other: The coverage map to merge.
  /// - Returns: The number of newly discovered edges added by the merge.
  @discardableResult
  public mutating func merge(_ other: Self) -> Int {
    let newBefore = observedEdgeCount
    let minBytes = min(bitmap.count, other.bitmap.count)
    for i in 0..<minBytes {
      bitmap[i] |= other.bitmap[i]
    }
    if other.bitmap.count > bitmap.count {
      bitmap.append(contentsOf: other.bitmap[minBytes...])
    }
    return observedEdgeCount - newBefore
  }

  /// Resets all edge observations to zero.
  public mutating func reset() {
    for i in bitmap.indices {
      bitmap[i] = 0
    }
  }
}
