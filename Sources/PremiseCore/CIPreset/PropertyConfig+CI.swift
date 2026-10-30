extension PropertyConfig {
  /// Balanced for CI pipelines — 500 runs, 60-second timeout.
  public static let ci = Self(
    maxRuns: 500,
    maxShrinkIterations: 1_000,
    maxDrawsPerRun: 10_000,
    timeoutSeconds: 60,
    derandomize: true,
    printReproductionBlob: true
  )
}
