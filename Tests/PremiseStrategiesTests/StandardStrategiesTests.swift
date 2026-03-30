import Testing

@testable import PremiseCore
@testable import PremiseStrategies

@Test("Integer strategy stays within bounds")
func integerStrategyStaysWithinBounds() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 3, maxDraws: 8))
  let value = try Strategy<Int>.integers(in: -3...3).draw(&data)
  #expect((-3...3).contains(value))
}

@Test("Boolean strategy produces a boolean value")
func booleanStrategyProducesBoolean() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 4, maxDraws: 8))
  let value = try Strategy<Bool>.booleans.draw(&data)
  #expect(value == true || value == false)
}

@Test("Float strategy stays within bounds")
func floatStrategyStaysWithinBounds() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 5, maxDraws: 8))
  let value = try Strategy<Double>.floats(in: -1.5...2.5).draw(&data)
  #expect((-1.5...2.5).contains(value))
}

@Test("Byte strategy uses the requested length")
func byteStrategyUsesRequestedLength() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 6, maxDraws: 8))
  let value = try Strategy<[UInt8]>.bytes(length: 4).draw(&data)
  #expect(value.count == 4)
}

@Test("String strategy respects the alphabet and length")
func stringStrategyRespectsAlphabetAndLength() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 7, maxDraws: 8))
  let value = try Strategy<String>.strings(from: ["a", "b"], length: 2...4).draw(&data)
  #expect((2...4).contains(value.count))
  #expect(value.allSatisfy { $0 == "a" || $0 == "b" })
}

@Test("Optional strategy can produce nil")
func optionalStrategyCanProduceNil() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 8, maxDraws: 8))
  let value = try Strategy<Int>.just(1).optional().draw(&data)
  #expect(value == nil || value == 1)
}
