import Foundation
import Testing

@testable import PremiseCore
@testable import PremiseStrategies

@Test("Data strategy respects fixed and ranged lengths")
func dataStrategyRespectsFixedAndRangedLengths() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 61, maxDraws: 64))

  let fixed = try Strategy<Data>.data(length: 4).draw(&data)
  let ranged = try Strategy<Data>.data(length: 1...8).draw(&data)

  #expect(fixed.count == 4)
  #expect((1...8).contains(ranged.count))
}

@Test("ASCII identifier strategy respects identifier shape")
func asciiIdentifierStrategyRespectsIdentifierShape() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 62, maxDraws: 64))
  let identifier = try Strategy<String>.asciiIdentifiers(length: 1...12).draw(&data)
  let first = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_")
  let rest = first.union(Set("0123456789"))

  #expect((1...12).contains(identifier.count))
  #expect(identifier.first.map { first.contains($0) } == true)
  #expect(identifier.allSatisfy { rest.contains($0) })
}

@Test("Custom identifier strategy uses supplied character sets")
func customIdentifierStrategyUsesSuppliedCharacterSets() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 63, maxDraws: 64))
  let identifier = try Strategy<String>.identifiers(
    first: ["$"],
    rest: ["a", "b"],
    length: 2...5
  ).draw(&data)

  #expect(identifier.first == "$")
  #expect(identifier.dropFirst().allSatisfy { $0 == "a" || $0 == "b" })
}

@Test("Custom identifier strategy permits single characters without rest")
func customIdentifierStrategyPermitsSingleCharactersWithoutRest() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 64, maxDraws: 64))
  let identifier = try Strategy<String>.identifiers(
    first: ["A"],
    rest: [],
    length: 1...1
  ).draw(&data)

  #expect(identifier == "A")
}
