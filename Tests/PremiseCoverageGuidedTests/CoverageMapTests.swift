import Testing

@testable import PremiseCoverageGuided

@Suite("CoverageMap Tests")
struct CoverageMapTests {
  @Test("Empty map has zero observed edges")
  func emptyMapHasZeroEdges() {
    let map = CoverageMap(capacity: 64)
    #expect(map.observedEdgeCount == 0)
  }

  @Test("Recording an edge increases observed count")
  func recordEdgeIncreasesCount() {
    var map = CoverageMap(capacity: 64)
    map.recordEdge(5)
    #expect(map.observedEdgeCount == 1)
    #expect(map.hasEdge(5))
  }

  @Test("Recording the same edge twice does not double count")
  func duplicateEdgeNotDoubleCounted() {
    var map = CoverageMap(capacity: 64)
    map.recordEdge(3)
    map.recordEdge(3)
    #expect(map.observedEdgeCount == 1)
  }

  @Test("Recording multiple distinct edges")
  func multipleDistinctEdges() {
    var map = CoverageMap(capacity: 64)
    map.recordEdge(0)
    map.recordEdge(7)
    map.recordEdge(15)
    #expect(map.observedEdgeCount == 3)
    #expect(map.hasEdge(0))
    #expect(map.hasEdge(7))
    #expect(map.hasEdge(15))
    #expect(!map.hasEdge(1))
  }

  @Test("Out-of-range edge index is silently ignored")
  func outOfRangeEdgeIgnored() {
    var map = CoverageMap(capacity: 16)
    map.recordEdge(100)
    map.recordEdge(-1)
    #expect(map.observedEdgeCount == 0)
    #expect(!map.hasEdge(100))
    #expect(!map.hasEdge(-1))
  }

  @Test("newEdges returns edges in other but not in self")
  func newEdgesDetectsNovelEdges() {
    var baseline = CoverageMap(capacity: 64)
    baseline.recordEdge(1)
    baseline.recordEdge(3)

    var snapshot = CoverageMap(capacity: 64)
    snapshot.recordEdge(1)
    snapshot.recordEdge(5)
    snapshot.recordEdge(9)

    let novel = baseline.newEdges(comparedTo: snapshot)
    #expect(novel.sorted() == [5, 9])
  }

  @Test("newEdges returns empty when snapshot is subset of baseline")
  func newEdgesEmptyForSubset() {
    var baseline = CoverageMap(capacity: 64)
    baseline.recordEdge(1)
    baseline.recordEdge(3)
    baseline.recordEdge(5)

    var snapshot = CoverageMap(capacity: 64)
    snapshot.recordEdge(1)
    snapshot.recordEdge(3)

    let novel = baseline.newEdges(comparedTo: snapshot)
    #expect(novel.isEmpty)
  }

  @Test("Merge combines edges from both maps")
  func mergeUnionsEdges() {
    var mapA = CoverageMap(capacity: 64)
    mapA.recordEdge(1)
    mapA.recordEdge(3)

    var mapB = CoverageMap(capacity: 64)
    mapB.recordEdge(3)
    mapB.recordEdge(5)

    let added = mapA.merge(mapB)
    #expect(added == 1)
    #expect(mapA.observedEdgeCount == 3)
    #expect(mapA.hasEdge(1))
    #expect(mapA.hasEdge(3))
    #expect(mapA.hasEdge(5))
  }

  @Test("Reset clears all edges")
  func resetClearsAllEdges() {
    var map = CoverageMap(capacity: 64)
    map.recordEdge(1)
    map.recordEdge(7)
    #expect(map.observedEdgeCount == 2)

    map.reset()
    #expect(map.observedEdgeCount == 0)
    #expect(!map.hasEdge(1))
    #expect(!map.hasEdge(7))
  }

  @Test("Capacity is rounded up to nearest byte boundary")
  func capacityRoundedUp() {
    let map = CoverageMap(capacity: 10)
    #expect(map.capacity == 16)
  }
}
