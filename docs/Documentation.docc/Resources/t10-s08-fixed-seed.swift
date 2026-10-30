import Testing
import PremiseCore
import PremiseTesting
import PremiseStrategies

@Test func cacheInsertionIsIdempotent() async throws {
  // Fix the seed: the same 100 inputs are generated on every run.
  // Useful for quick local reproducibility; less useful than stored traces
  // because the inputs change if you change the strategy.
  let config = PropertyConfig(seed: 12345)

  try await forAll(keyStrategy, config: config) { key in
    try await forAll(valueStrategy, config: config) { value in
      let cache = BuggyCache()
      cache.insert(value, forKey: key)
      cache.insert(value, forKey: key)
      #expect(cache.totalInsertions() == 1)
    }
  }
}
