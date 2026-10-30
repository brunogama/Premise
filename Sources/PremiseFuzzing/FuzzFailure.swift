import Foundation
import PremiseCore

/// Error thrown when a fuzzer input triggers a property failure.
public struct FuzzFailure: Error, Sendable, CustomStringConvertible {
  /// Raw fuzzer input bytes.
  public let input: [UInt8]
  /// Stable property identity used for persistence.
  public let propertyID: PropertyIdentity
  /// Trace that replays the failing strategy choices.
  public let trace: ChoiceTrace
  /// String form of the underlying error.
  public let underlyingDescription: String

  /// Creates a failure with its input, identity, trace, and cause.
  public init(
    input: [UInt8],
    propertyID: PropertyIdentity,
    trace: ChoiceTrace,
    underlyingDescription: String
  ) {
    self.input = input
    self.propertyID = propertyID
    self.trace = trace
    self.underlyingDescription = underlyingDescription
  }

  /// Foundation data view of ``input``.
  public var inputData: Data { Data(input) }

  /// Copy-paste reproduction blob for the failing trace, when encodable.
  public var reproductionBlob: String? { try? trace.reproductionBlob() }

  /// A diagnostic summary of this failure.
  public var description: String {
    var parts = [
      "Fuzz input failed",
      "property=\(propertyID.fileID):\(propertyID.line)",
      "strategy=\(propertyID.strategyLabel)",
      "bytes=\(input.count)",
      "traceEntries=\(trace.entries.count)",
      "underlying=\(underlyingDescription)",
    ]
    if let reproductionBlob {
      parts.append("reproductionBlob=\(reproductionBlob)")
    }
    return parts.joined(separator: ", ")
  }
}
