/// Per-property execution configuration frozen in Phase 1.
public struct PropertyConfig: Sendable {
  public var maxRuns: Int
  public var maxShrinkIterations: Int
  public var maxDrawsPerRun: Int
  public var seed: UInt64?
  public var replayEnabled: Bool

  public init(
    maxRuns: Int = 100,
    maxShrinkIterations: Int = 500,
    maxDrawsPerRun: Int = 10_000,
    seed: UInt64? = nil,
    replayEnabled: Bool = true
  ) {
    self.maxRuns = maxRuns
    self.maxShrinkIterations = maxShrinkIterations
    self.maxDrawsPerRun = maxDrawsPerRun
    self.seed = seed
    self.replayEnabled = replayEnabled
  }

  public static let `default` = Self()
}
