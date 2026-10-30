/// A simple complex-number value used by Premise's numeric strategies.
public struct PremiseComplex:
  Sendable, Codable, Equatable, CustomStringConvertible
{
  /// Real component.
  public let real: Double

  /// Imaginary component.
  public let imaginary: Double

  /// Creates a complex number from real and imaginary components.
  public init(real: Double, imaginary: Double) {
    self.real = real
    self.imaginary = imaginary
  }

  /// Textual `real+imaginaryi` representation.
  public var description: String { "\(real)+\(imaginary)i" }
}
