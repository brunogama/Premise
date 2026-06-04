import Foundation

/// Per-property execution configuration.
///
/// Use the memberwise initialiser for full control, or the chainable
/// builder methods and presets for ergonomic one-liners:
///
/// ```swift
/// // Memberwise:
/// let config = PropertyConfig(maxRuns: 500, seed: 42)
///
/// // Builder:
/// let config = PropertyConfig.default
///     .runs(500)
///     .seed(42)
///     .noShrink()
///
/// // Presets:
/// let config: PropertyConfig = .quick       // 20 runs, fast feedback
/// let config: PropertyConfig = .thorough    // 1_000 runs, deep exploration
/// let config: PropertyConfig = .ci          // 500 runs, balanced for CI
/// ```
public struct PropertyConfig: Sendable {
  public var maxRuns: Int
  public var maxShrinkIterations: Int
  public var maxDrawsPerRun: Int
  public var seed: UInt64?
  public var replayEnabled: Bool
  public var localDatabaseDirectory: URL?
  public var committedCorpusDirectory: URL?
  public var traceExportDirectory: URL?
  /// Per-property wall-clock timeout in seconds.  When non-nil, the runner
  /// will stop after the deadline is exceeded and report the best failure
  /// found so far (or pass if none).
  public var timeoutSeconds: Double?
  public var phases: [PropertyPhase]
  public var healthChecks: [HealthCheck]

  public init(
    maxRuns: Int = 100,
    maxShrinkIterations: Int = 500,
    maxDrawsPerRun: Int = 10_000,
    seed: UInt64? = nil,
    replayEnabled: Bool = true,
    localDatabaseDirectory: URL? = nil,
    committedCorpusDirectory: URL? = nil,
    traceExportDirectory: URL? = nil,
    timeoutSeconds: Double? = nil,
    phases: [PropertyPhase] = .premiseDefault,
    healthChecks: [HealthCheck] = HealthCheck.allCases
  ) {
    self.maxRuns = maxRuns
    self.maxShrinkIterations = maxShrinkIterations
    self.maxDrawsPerRun = maxDrawsPerRun
    self.seed = seed
    self.replayEnabled = replayEnabled
    self.localDatabaseDirectory = localDatabaseDirectory
    self.committedCorpusDirectory = committedCorpusDirectory
    self.traceExportDirectory = traceExportDirectory
    self.timeoutSeconds = timeoutSeconds
    self.phases = phases
    self.healthChecks = healthChecks
  }

  public static let `default` = Self()

  // MARK: - Presets

  /// Fast feedback during development — 20 runs, 100 shrink iterations.
  public static let quick = Self(
    maxRuns: 20,
    maxShrinkIterations: 100,
    maxDrawsPerRun: 5_000
  )

  /// Deep exploration — 1,000 runs, 2,000 shrink iterations.
  public static let thorough = Self(
    maxRuns: 1_000,
    maxShrinkIterations: 2_000,
    maxDrawsPerRun: 20_000
  )

  /// Balanced for CI pipelines — 500 runs, 60-second timeout.
  public static let ci = Self(
    maxRuns: 500,
    maxShrinkIterations: 1_000,
    maxDrawsPerRun: 10_000,
    timeoutSeconds: 60
  )

  // MARK: - Chainable builders

  /// Sets the number of property runs.
  public func runs(_ count: Int) -> Self {
    var copy = self
    copy.maxRuns = count
    return copy
  }

  /// Sets the maximum shrink iterations.
  public func shrinkIterations(_ count: Int) -> Self {
    var copy = self
    copy.maxShrinkIterations = count
    return copy
  }

  /// Disables shrinking entirely.
  public func noShrink() -> Self {
    var copy = self
    copy.maxShrinkIterations = 0
    return copy
  }

  /// Fixes the base seed for deterministic reproduction.
  public func seed(_ seed: UInt64) -> Self {
    var copy = self
    copy.seed = seed
    return copy
  }

  /// Sets the per-run draw budget.
  public func drawBudget(_ max: Int) -> Self {
    var copy = self
    copy.maxDrawsPerRun = max
    return copy
  }

  /// Disables replay of previously persisted failures.
  public func noReplay() -> Self {
    var copy = self
    copy.replayEnabled = false
    return copy
  }

  /// Sets the writable local failure database directory.
  public func storingFailures(in directory: URL) -> Self {
    var copy = self
    copy.localDatabaseDirectory = directory
    return copy
  }

  /// Sets a source-controlled replay corpus directory.
  public func replayingCorpus(from directory: URL) -> Self {
    var copy = self
    copy.committedCorpusDirectory = directory
    return copy
  }

  /// Sets the directory where JSON failure trace artifacts are written.
  public func exportingFailureTraces(to directory: URL) -> Self {
    var copy = self
    copy.traceExportDirectory = directory
    return copy
  }

  /// Sets a wall-clock timeout in seconds.
  public func timeout(seconds: Double) -> Self {
    var copy = self
    copy.timeoutSeconds = seconds
    return copy
  }

  /// Selects the execution phases and their order.
  public func phases(_ phases: [PropertyPhase]) -> Self {
    var copy = self
    copy.phases = phases
    return copy
  }

  /// Selects non-fatal health checks.
  public func healthChecks(_ checks: [HealthCheck]) -> Self {
    var copy = self
    copy.healthChecks = checks
    return copy
  }
}
