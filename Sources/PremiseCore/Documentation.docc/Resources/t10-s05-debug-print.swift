import Testing
import PremiseTesting
import PremiseStrategies

let keyStrategy = Strategy<String>.strings(from: Array("abc"), length: 1...3)
let valueStrategy = Strategy<Int>.integers(in: 0...100)

@Test func cacheInsertionIsIdempotent() async throws {
  try await forAll(keyStrategy) { key in
    try await forAll(valueStrategy) { value in
      // Add a print to observe exactly what the replay produces.
      // Because replay is deterministic, this always prints the same values.
      print("Testing key=\(key) value=\(value)")

      let cache = BuggyCache()
      cache.insert(value, forKey: key)
      cache.insert(value, forKey: key)
      print("  uniqueKeyCount=\(cache.uniqueKeyCount()) totalInsertions=\(cache.totalInsertions())")

      #expect(cache.totalInsertions() == 1)
    }
  }
}
// Output during replay:
// Testing key="a" value=0
//   uniqueKeyCount=1 totalInsertions=2  ← the bug is clear
