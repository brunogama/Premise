/// Stable property identifier shared between the runner and persistence.
///
/// The primary identity key is `fileID + functionName + strategyLabel`.
/// The `line` field is kept for diagnostics but is **not** used in
/// equality/hashing so that moving code within a file does not orphan
/// previously persisted examples.
public struct PropertyIdentity: Hashable, Sendable, Codable {
  public let fileID: String
  public let line: UInt
  public let strategyLabel: String

  /// The enclosing function name captured via `#function`.
  ///
  /// When non-nil this is used as the primary identity component
  /// instead of `line`, making persisted examples resilient to
  /// file-level refactors.
  public let functionName: String?

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

  public func hash(into hasher: inout Hasher) {
    hasher.combine(fileID)
    hasher.combine(functionName ?? "L\(line)")
    hasher.combine(strategyLabel)
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.fileID == rhs.fileID
      && (lhs.functionName ?? "L\(lhs.line)") == (rhs.functionName ?? "L\(rhs.line)")
      && lhs.strategyLabel == rhs.strategyLabel
  }
}
