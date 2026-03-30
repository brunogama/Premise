import Testing
import PremiseTesting
import PremiseStrategies

// Fixed: only increment insertionCount for new keys.
final class BuggyCache: @unchecked Sendable {
  private var store: [String: Int] = [:]
  private var insertionCount = 0

  func insert(_ value: Int, forKey key: String) {
    let isNew = store[key] == nil
    store[key] = value
    if isNew { insertionCount += 1 }  // Fixed
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
      cache.insert(value, forKey: key)
      // Stored trace ("a", 0) is replayed first → now passes.
      // Then 99 fresh cases run and all pass.
      #expect(cache.totalInsertions() == 1)
    }
  }
}
