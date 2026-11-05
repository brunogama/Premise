import Testing
import PremiseTesting
import PremiseStrategies

struct Temperature: Sendable {
  let celsius: Double
  var fahrenheit: Double { celsius * 9 / 5 + 32 }
}

// Chain map to convert the generated Double into a domain type.
let temperatures = Strategy<Double>.floats(in: -273.15...1000.0)
  .map { Temperature(celsius: $0) }

@Test func fahrenheitConversionIsConsistent() async throws {
  try await forAll(temperatures) { temperature in
    let backToCelsius = (temperature.fahrenheit - 32) * 5 / 9
    #expect(abs(backToCelsius - temperature.celsius) < 0.001)
  }
}
