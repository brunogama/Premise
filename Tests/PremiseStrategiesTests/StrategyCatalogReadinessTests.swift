import Foundation
import Testing

@testable import PremiseCore
@testable import PremiseStrategies

@Test("catalog string strategies cover regex network and email shapes")
func catalogStringStrategiesCoverRegexNetworkAndEmailShapes() throws {
  let provider = PseudoRandomProvider(seed: 41, maxDraws: 512)
  var data = PremiseData(provider: provider)

  let regex = try Strategy<String>.regex("[a-c]{2}[0-9]").draw(&data)
  let domain = try Strategy<String>.domainNames(labels: 2...2).draw(&data)
  let email = try Strategy<String>.emailAddresses().draw(&data)
  let ipv4 = try Strategy<String>.ipv4Addresses().draw(&data)
  let ipv6 = try Strategy<String>.ipv6Addresses().draw(&data)

  #expect(regex.count == 3)
  #expect(regex.prefix(2).allSatisfy { ["a", "b", "c"].contains($0) })
  #expect(regex.last?.isNumber == true)
  #expect(domain.contains("."))
  #expect(email.contains("@"))
  #expect(ipv4.split(separator: ".").count == 4)
  #expect(ipv6.contains(":"))
}

@Test("catalog url date uuid and range strategies draw valid values")
func catalogURLDateUUIDAndRangeStrategiesDrawValidValues() throws {
  let provider = PseudoRandomProvider(seed: 42, maxDraws: 512)
  var data = PremiseData(provider: provider)

  let (url, zone) = try drawWebAndTimeZone(&data)
  let date = try Strategy<DateComponents>.dateTimes(years: 2020...2021)
    .draw(&data)
  let duration = try Strategy<Duration>.durations(seconds: -2...2).draw(&data)
  let nilUUID = try Strategy<UUID>.nilUUID.draw(&data)
  let index = try Strategy<Int>.indices(in: 0..<3).draw(&data)
  let range = try Strategy<Range<Int>>.ranges(in: 0..<5).draw(&data)
  let closed = try Strategy<ClosedRange<Int>>.closedRanges(in: 0...5)
    .draw(&data)

  #expect(["http", "https"].contains(url.scheme))
  #expect(url.host != nil)
  #expect(zone == TimeZone(identifier: "UTC"))
  #expect((2020...2021).contains(date.year ?? 0))
  #expect(duration >= .seconds(-2) && duration <= .seconds(2))
  #expect(nilUUID.uuidString == "00000000-0000-0000-0000-000000000000")
  #expect((0..<3).contains(index))
  #expect(range.lowerBound >= 0 && range.upperBound <= 5)
  #expect(closed.lowerBound >= 0 && closed.upperBound <= 5)
}

private func drawWebAndTimeZone(
  _ data: inout PremiseData
) throws -> (URL, TimeZone) {
  let url = try Strategy<URL>.web(maxPathSegments: 2, maxQueryItems: 1)
    .draw(&data)
  let zone = try Strategy<TimeZone>.timeZones(identifiers: ["UTC"]).draw(&data)
  return (url, zone)
}

@Test("catalog numeric strategies draw decimal rational and complex values")
func catalogNumericStrategiesDrawDecimalRationalAndComplexValues() throws {
  let provider = PseudoRandomProvider(seed: 43, maxDraws: 128)
  var data = PremiseData(provider: provider)

  let decimal = try Strategy<Decimal>.decimals(mantissa: -10...10, scale: 0...2)
    .draw(&data)
  let rational = try Strategy<PremiseRational>
    .rationals(numerator: -10...10, denominator: 1...10).draw(&data)
  let complex = try Strategy<PremiseComplex>
    .complexNumbers(real: -1...1, imaginary: -1...1).draw(&data)

  #expect(decimal >= Decimal(-10) && decimal <= Decimal(10))
  #expect(rational.denominator > 0)
  #expect((-1...1).contains(complex.real))
  #expect((-1...1).contains(complex.imaginary))
}
