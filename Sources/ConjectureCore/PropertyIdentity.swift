/// Stable property identifier shared between the runner and persistence.
public struct PropertyIdentity: Hashable, Sendable, Codable {
  public let fileID: String
  public let line: UInt
  public let strategyLabel: String

  public init(fileID: String, line: UInt, strategyLabel: String) {
    self.fileID = fileID
    self.line = line
    self.strategyLabel = strategyLabel
  }
}
