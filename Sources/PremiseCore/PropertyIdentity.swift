/// Stable property identifier shared between the runner and persistence.
///
/// The primary identity key is `fileID + functionName + strategyLabel`.
/// The `line` field is kept for diagnostics but is **not** used in
/// equality/hashing so that moving code within a file does not orphan
/// previously persisted examples.
public struct PropertyIdentity: Hashable, Sendable, Codable {
  /// The source file containing the property.
  public let fileID: String
  /// The source line used for diagnostics and as an identity fallback.
  public let line: UInt
  /// The label of the strategy under test.
  public let strategyLabel: String

  /// The enclosing function name captured via `#function`.
  ///
  /// When non-nil this is used as the primary identity component
  /// instead of `line`, making persisted examples resilient to
  /// file-level refactors.
  public let functionName: String?

  /// Creates an identity from its source location and strategy label.
  public init(
    fileID: String,
    line: UInt,
    strategyLabel: String,
    functionName: String? = nil
  ) {
    self.fileID = fileID
    self.line = line
    self.strategyLabel = strategyLabel
    self.functionName = functionName
  }

  // MARK: - Hashable (stable across line moves)

  /// Hashes the stable identity components.
  public func hash(into hasher: inout Hasher) {
    hasher.combine(fileID)
    hasher.combine(functionName ?? "L\(line)")
    hasher.combine(strategyLabel)
  }

  /// Compares stable identity components, using the line as a fallback.
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.fileID == rhs.fileID
      && (lhs.functionName ?? "L\(lhs.line)") == (rhs.functionName ?? "L\(rhs.line)")
      && lhs.strategyLabel == rhs.strategyLabel
  }
}
