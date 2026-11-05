import Foundation
import PremiseCore

// MARK: - Decimal, rational, and complex numbers

public extension Strategy where Value == Decimal {
  /// Generates Decimal values by drawing an integer mantissa and decimal scale.
  static func decimals(
    mantissa: ClosedRange<Int> = -1_000_000...1_000_000,
    scale: ClosedRange<Int> = 0...6
  ) -> Strategy<Decimal> {
    Strategy<Decimal>(
      label: "decimals(mantissa: \(mantissa), scale: \(scale))",
      draw: { data in
        var value = Decimal(data.drawInteger(in: mantissa))
        let scaleValue = data.drawInteger(in: scale)
        if scaleValue > 0 {
          value /= Decimal(pow10(scaleValue))
        }
        return value
      },
      shrink: { value in value == 0 ? [] : [0] }
    )
  }
}

public extension Strategy where Value == PremiseRational {
  static func rationals(
    numerator: ClosedRange<Int> = -1_000...1_000,
    denominator: ClosedRange<Int> = 1...1_000
  ) -> Strategy<PremiseRational> {
    Strategy<PremiseRational>(
      label: "rationals",
      draw: { data in
        PremiseRational(
          numerator: data.drawInteger(in: numerator),
          denominator: max(1, data.drawInteger(in: denominator))
        )
      },
      shrink: { value in
        value == PremiseRational(numerator: 0, denominator: 1)
          ? [] : [PremiseRational(numerator: 0, denominator: 1)]
      }
    )
  }
}

public extension Strategy where Value == PremiseComplex {
  static func complexNumbers(
    real: ClosedRange<Double> = -1_000...1_000,
    imaginary: ClosedRange<Double> = -1_000...1_000
  ) -> Strategy<PremiseComplex> {
    Strategy<PremiseComplex>(
      label: "complexNumbers",
      draw: { data in
        PremiseComplex(
          real: try Strategy<Double>.floats(in: real).draw(&data),
          imaginary: try Strategy<Double>.floats(in: imaginary).draw(&data)
        )
      },
      shrink: { value in
        value == PremiseComplex(real: 0, imaginary: 0)
          ? [] : [PremiseComplex(real: 0, imaginary: 0)]
      }
    )
  }
}
private func pow10(_ exponent: Int) -> Int {
  guard exponent > 0 else { return 1 }
  return (0..<min(exponent, 18)).reduce(1) { value, _ in value * 10 }
}
