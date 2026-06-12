#if canImport(Testing) && canImport(PremiseTesting) && canImport(PremiseStrategies)
import Testing
import PremiseTesting
import PremiseStrategies

// A cache with a bug: inserting the same key twice increments the count twice.
final class BuggyCache {
  private var store: [String: Int] = [:]
  private var insertionCount = 0

  func insert(_ value: Int, forKey key: String) {
    store[key] = value
    insertionCount += 1  // Bug: should only count unique keys
  }

  func uniqueKeyCount() -> Int { store.keys.count }
  func totalInsertions() -> Int { insertionCount }
}

let keyStrategy = Strategy<String>.strings(from: Array("abc"), length: 1...3)
let valueStrategy = Strategy<Int>.integers(in: 0...100)

@Test func cacheInsertionIsIdempotent() async throws {
  try await forAll(keyStrategy) { key in
    try await forAll(valueStrategy) { value in
      let cache = BuggyCache()
      cache.insert(value, forKey: key)
      cache.insert(value, forKey: key)  // inserting same key/value twice

      // Idempotence: two insertions of the same pair == one insertion.
      #expect(cache.uniqueKeyCount() == 1)
      // This passes. But insertion count is 2, not 1 — the bug is elsewhere.
      #expect(cache.totalInsertions() == 1)  // ← this will fail
    }
  }
}
#endif
