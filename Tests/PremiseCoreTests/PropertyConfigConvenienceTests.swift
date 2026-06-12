import Testing

@testable import PremiseCore

@Test("bounded config maps explicit budgets")
func boundedConfigMapsExplicitBudgets() {
  let config = PropertyConfig.bounded(
    runs: 40,
    shrinks: 160,
    drawBudget: 2_000,
    replay: false
  )

  #expect(config.maxRuns == 40)
  #expect(config.maxShrinkIterations == 160)
  #expect(config.maxDrawsPerRun == 2_000)
  #expect(config.replayEnabled == false)
}

@Test("bounded config keeps default draw budget")
func boundedConfigKeepsDefaultDrawBudget() {
  let config = PropertyConfig.bounded(runs: 3)

  #expect(config.maxRuns == 3)
  #expect(config.maxShrinkIterations == 100)
  #expect(config.maxDrawsPerRun == PropertyConfig.default.maxDrawsPerRun)
  #expect(config.replayEnabled)
}
