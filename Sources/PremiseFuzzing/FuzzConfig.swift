import Foundation
import PremiseCore

/// Configuration for bridging byte-oriented fuzzers to Premise strategies.
public struct FuzzConfig: Sendable {
  /// Stable identity used when saving failing fuzz inputs.
  public var propertyID: PropertyIdentity
  /// Directory for persisted failure traces. `nil` disables persistence.
  public var databaseDirectory: URL?
  /// Whether failures should be saved to the configured database directory.
  public var saveFailures: Bool

  /// Creates fuzzing configuration.
  public init(
    propertyID: PropertyIdentity = PropertyIdentity(
      fileID: #fileID,
      line: UInt(#line),
      strategyLabel: "fuzz",
      functionName: #function
    ),
    databaseDirectory: URL? = URL(
      fileURLWithPath: ".premise/fuzz",
      isDirectory: true
    ),
    saveFailures: Bool = true
  ) {
    self.propertyID = propertyID
    self.databaseDirectory = databaseDirectory
    self.saveFailures = saveFailures
  }

  /// Returns a copy that stores failures under `directory`.
  public func storingFailures(in directory: URL) -> Self {
    var copy = self
    copy.databaseDirectory = directory
    copy.saveFailures = true
    return copy
  }

  /// Returns a copy that does not write failure traces.
  public func withoutPersistence() -> Self {
    var copy = self
    copy.databaseDirectory = nil
    copy.saveFailures = false
    return copy
  }
}
