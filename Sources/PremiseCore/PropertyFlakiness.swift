/// Errors raised when a property failure cannot be reproduced reliably.
public enum PropertyFlakiness: Error, Sendable, Equatable,
  CustomStringConvertible
{
  /// A failure was observed once, but replaying its trace did not fail again.
  case failureNotReproducible(originalError: String)

  /// Replaying a failing trace produced a different error.
  case failureChanged(originalError: String, replayedError: String)

  /// A description of how replay differed from the original failure.
  public var description: String {
    switch self {
    case .failureNotReproducible(let originalError):
      return "Flaky failure: trace did not reproduce original error: \(originalError)"
    case .failureChanged(let originalError, let replayedError):
      return "Flaky failure: replay changed from `\(originalError)` to `\(replayedError)`."
    }
  }
}
