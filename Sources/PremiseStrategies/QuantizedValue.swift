/// Quantized numeric value with a raw integer bucket and floating scale.
public struct QuantizedValue: Sendable, Equatable, Codable {
  /// Integer bucket.
  public var raw: Int
  /// Scale applied to the bucket.
  public var scale: Double

  /// Creates a quantized value from its bucket and scale.
  public init(raw: Int, scale: Double) {
    self.raw = raw
    self.scale = scale
  }

  /// Floating-point value of the bucket.
  public var value: Double {
    Double(raw) * scale
  }
}
