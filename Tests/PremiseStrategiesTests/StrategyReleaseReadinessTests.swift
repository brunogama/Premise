import Testing

@testable import PremiseCore
@testable import PremiseStrategies

@Test("suchThat filters generated values")
func suchThatFiltersGeneratedValues() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 1, maxDraws: 32))
  let even = Strategy<Int>.integers(in: 0...20).suchThat { $0.isMultiple(of: 2) }
  let value = try even.draw(&data)
  #expect(value.isMultiple(of: 2))
}

@Test("sized generation passes a bounded size to the builder")
func sizedGenerationPassesBoundedSizeToBuilder() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 2, maxDraws: 32))
  let strategy = Strategy<[Int]>.sized(maxSize: 8) { size in
    .arrays(of: .just(size), count: size)
  }
  let value = try strategy.draw(&data)
  #expect(value.count <= 8)
  #expect(value.allSatisfy { $0 == value.count })
}

@Test("tuple zip delegates value shrinking to each component")
func tupleZipDelegatesValueShrinkingToEachComponent() {
  let pair = zip(
    Strategy<Int>.integers(in: 0...10),
    Strategy<Bool>.booleans
  )
  let shrinks = pair.shrink((8, true))
  #expect(shrinks.contains { $0.0 == 0 && $0.1 == true })
  #expect(shrinks.contains { $0.0 == 8 && $0.1 == false })
}

@Test("collection generators support exact and min max sizes")
func collectionGeneratorsSupportExactAndMinMaxSizes() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 3, maxDraws: 64))

  let exact = try Strategy<Int>.arrays(of: .just(1), count: 3).draw(&data)
  let ranged = try Strategy<Int>.arrays(of: .just(2), minCount: 2, maxCount: 4).draw(&data)
  let set = try Strategy.sets(of: Strategy<Int>.integers(in: 0...10), minCount: 1, maxCount: 3)
    .draw(&data)

  #expect(exact.count == 3)
  #expect((2...4).contains(ranged.count))
  #expect((1...3).contains(set.count))
}

@Test("set and dictionary generators reject impossible unique counts")
func setAndDictionaryGeneratorsRejectImpossibleUniqueCounts() {
  var setData = PremiseData(provider: PseudoRandomProvider(seed: 30, maxDraws: 128))
  #expect(throws: StrategyError.self) {
    try Strategy.sets(of: Strategy<Int>.just(1), count: 2).draw(&setData)
  }

  var dictionaryData = PremiseData(provider: PseudoRandomProvider(seed: 31, maxDraws: 128))
  #expect(throws: StrategyError.self) {
    try Strategy.dictionaries(
      keys: Strategy<String>.just("duplicate"),
      values: Strategy<Int>.integers(in: 0...10),
      count: 2
    )
    .draw(&dictionaryData)
  }
}

@Test("floating edge strategy can include NaN infinity denormals and epsilon values")
func floatingEdgeStrategyIncludesRequestedCases() {
  let strategy = Strategy<Double>.edgeCaseFloats(
    in: -1.0...1.0,
    includeNaN: true,
    includeInfinity: true,
    includeDenormals: true,
    epsilonAround: 0.5
  )
  let samples = strategy.sample(count: 128, seed: 4)
  #expect(samples.contains { $0.isNaN })
  #expect(samples.contains { $0.isInfinite })
  #expect(samples.contains { $0 == Double.leastNonzeroMagnitude })
  #expect(samples.contains { abs($0 - 0.5) <= Double.ulpOfOne })
}

@Test("floating exceptional edge cases bypass finite range filtering")
func floatingExceptionalEdgeCasesBypassFiniteRangeFiltering() throws {
  let strategy = Strategy<Double>.edgeCaseFloats(
    in: 1.0...2.0,
    includeNaN: true,
    includeInfinity: true
  )

  var nanData = replayingEdgeCandidate(index: 2)
  var positiveInfinityData = replayingEdgeCandidate(index: 3)
  var negativeInfinityData = replayingEdgeCandidate(index: 4)

  #expect(try strategy.draw(&nanData).isNaN)
  #expect(try strategy.draw(&positiveInfinityData) == .infinity)
  #expect(try strategy.draw(&negativeInfinityData) == -Double.infinity)
}

private struct BoxedInt: Sendable, Equatable {
  var value: Int
}

@Test("custom domain strategies can replace shrinkers")
func customDomainStrategiesCanReplaceShrinkers() {
  let strategy = Strategy<BoxedInt>.just(BoxedInt(value: 10))
    .shrinking { box in
      box.value > 0 ? [BoxedInt(value: 0)] : []
    }

  #expect(strategy.shrink(BoxedInt(value: 10)) == [BoxedInt(value: 0)])
}

@Test("vector and index helpers produce shrinkable domain values")
func vectorAndIndexHelpersProduceShrinkableDomainValues() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 5, maxDraws: 128))

  let dimensions = try Strategy<Int>.dimensions(in: 2...8).draw(&data)
  let vector = try Strategy<[Double]>.denseVector(
    dimensions: 3,
    elements: .edgeCaseFloats(in: -1.0...1.0)
  ).draw(&data)
  let sparse = try Strategy<SparseVector>.sparseVector(
    dimensions: 5,
    nonZeroCount: 1...3,
    values: .edgeCaseFloats(in: -10.0...10.0)
  ).draw(&data)
  let quantized = try Strategy<QuantizedValue>.quantizedValues(raw: -10...10, scale: 0.25)
    .draw(&data)
  let operation = try Strategy<IndexOperation>.indexOperations(indexRange: 0...4, value: -5...5)
    .draw(&data)

  #expect((2...8).contains(dimensions))
  #expect(vector.count == 3)
  #expect(sparse.dimensions == 5)
  #expect(sparse.entries.count <= 3)
  #expect(quantized.value == Double(quantized.raw) * 0.25)
  #expect((0...4).contains(operation.index))
}

private func replayingEdgeCandidate(index: UInt64) -> PremiseData {
  PremiseData(
    provider: ReplayProvider(
      trace: ChoiceTrace(entries: [.integer(0), .integer(index)])
    )
  )
}
