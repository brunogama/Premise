import Testing

@testable import PremiseCore
@testable import PremiseStrategies

@Test("map transforms the drawn value")
func mapTransformsTheDrawnValue() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 11, maxDraws: 8))
  let mapped = Strategy<Int>.just(2).map { $0 * 3 }
  let value = try mapped.draw(&data)
  #expect(value == 6)
}

@Test("flatMap preserves dependent generation")
func flatMapPreservesDependentGeneration() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 12, maxDraws: 8))
  let flatMapped = Strategy<Int>.just(3).flatMap { length in
    Strategy<[UInt8]>.bytes(length: length)
  }
  let value = try flatMapped.draw(&data)
  #expect(value.count == 3)
}

@Test("filter enforces the predicate")
func filterEnforcesThePredicate() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 13, maxDraws: 8))
  let strategy = Strategy<Int>.oneOf([.just(1), .just(3)]).filter { $0 == 3 }
  let value = try strategy.draw(&data)
  #expect(value == 3)
}

@Test("oneOf selects from the provided strategies")
func oneOfSelectsFromTheProvidedStrategies() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 14, maxDraws: 8))
  let value = try Strategy<Int>.oneOf([.just(1), .just(2), .just(3)]).draw(&data)
  #expect([1, 2, 3].contains(value))
}

@Test("frequency selects one of the weighted strategies")
func frequencySelectsOneOfTheWeightedStrategies() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 15, maxDraws: 8))
  let value = try Strategy<Int>.frequency([(1, .just(10)), (3, .just(20))]).draw(&data)
  #expect([10, 20].contains(value))
}
