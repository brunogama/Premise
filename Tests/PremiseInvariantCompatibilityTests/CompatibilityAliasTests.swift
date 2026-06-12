import Testing

import PremiseInvariantCompatibility

@available(*, deprecated, message: "Exercises deprecated compatibility aliases.")
@Test("Compatibility aliases map to native Premise types")
func compatibilityAliasesMapToNativePremiseTypes() async throws {
  let generator: Gen<Int> = .integers(in: 0...3)
  let seed: Seed = 7
  let shrink: Shrink<Int> = { value in value > 0 ? [0] : [] }
  let property: ThrowingProperty<Int> = { value in value >= 0 }
  let zipped: Zip2Generator<Int, Bool> = zip(generator, .booleans)

  #expect(generator.sampleOne(seed: seed) != nil)
  #expect(shrink(2) == [0])
  #expect(try property(1))
  #expect(zipped.sampleOne(seed: seed) != nil)
}
