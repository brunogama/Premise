import Foundation
import PremiseCore

/// Failure records from intentionally failing properties must not land in the
/// repository working tree; store them in a unique temporary directory.
func isolatedFailureStorage(_ config: PropertyConfig = PropertyConfig()) -> PropertyConfig {
  config.storingFailures(
    in: FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
  )
}
