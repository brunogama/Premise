/// Error reported when an example exceeds its configured deadline.
public struct PropertyDeadlineExceeded: Error, Sendable, Equatable,
  CustomStringConvertible
{
  /// Observed example runtime in seconds.
  public let elapsedSeconds: Double

  /// Configured deadline in seconds.
  public let deadlineSeconds: Double

  /// Creates a deadline error with observed and configured durations.
  public init(elapsedSeconds: Double, deadlineSeconds: Double) {
    self.elapsedSeconds = elapsedSeconds
    self.deadlineSeconds = deadlineSeconds
  }

  /// A description of the exceeded deadline.
  public var description: String {
    "Example exceeded deadline: elapsed=\(elapsedSeconds)s deadline=\(deadlineSeconds)s"
  }
}
