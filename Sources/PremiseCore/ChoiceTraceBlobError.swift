/// Errors raised while decoding or encoding stable Premise replay blobs.
public enum ChoiceTraceBlobError: Error, Equatable, Sendable,
  CustomStringConvertible
{
  /// The binary payload does not start with Premise's trace magic header.
  case badMagic

  /// The binary payload uses a trace version this runtime cannot decode.
  case unsupportedVersion(found: UInt16, supported: ClosedRange<UInt16>)

  /// The binary payload ended before a complete field could be decoded.
  case truncated

  /// The copy-paste blob did not contain valid base64-url data.
  case invalidBase64

  /// The blob prefix is not one of the supported Premise replay blob prefixes.
  case invalidBlobPrefix(String)

  /// The payload is structurally invalid.
  case malformed(String)

  /// A description of the decoding or encoding error.
  public var description: String {
    switch self {
    case .badMagic:
      return "Replay blob does not use the Premise trace magic header."
    case .unsupportedVersion(let found, let supported):
      return "Unsupported Premise trace blob version: found=\(found), supported=\(supported)."
    case .truncated:
      return "Replay blob ended before a complete trace could be decoded."
    case .invalidBase64:
      return "Replay blob does not contain valid base64-url data."
    case .invalidBlobPrefix(let prefix):
      return "Unsupported Premise replay blob prefix: \(prefix)."
    case .malformed(let message):
      return "Malformed Premise replay blob: \(message)"
    }
  }
}
