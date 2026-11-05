extension PropertyConfig {
  // CI is the established public name for continuous integration.
  // swiftlint:disable identifier_name
  /// Balanced for CI pipelines: 500 runs, 60-second timeout.
  public static let ci = Self(
    // swiftlint:enable identifier_name
    maxRuns: 500,
    maxShrinkIterations: 1_000,
    maxDrawsPerRun: 10_000,
    timeoutSeconds: 60,
    derandomize: true,
    printReproductionBlob: true
  )
}
