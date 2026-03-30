/// Configuration for parallel property execution.
///
/// Controls the maximum number of concurrent runs when using
/// ``ParallelRunner``. The default allows the Swift runtime to
/// choose concurrency based on available system resources.
public struct ParallelConfig: Sendable {
  /// Maximum number of concurrent runs to schedule.
  ///
  /// When `nil`, the task group is allowed to schedule all runs
  /// concurrently and the Swift runtime manages parallelism.
  public var maxConcurrentRuns: Int?

  /// Creates a parallel execution configuration.
  ///
  /// - Parameter maxConcurrentRuns: The maximum number of runs to
  ///   schedule concurrently. Pass `nil` to let the runtime decide.
  public init(maxConcurrentRuns: Int? = nil) {
    self.maxConcurrentRuns = maxConcurrentRuns
  }

  /// Default configuration with runtime-managed concurrency.
  public static let `default` = Self()
}
