import Testing

import PremiseCore
import PremiseTesting

@Test("forAll supports four heterogeneous strategies")
func variadicForAllSync() async throws {
  try await forAll(
    Strategy<Int>.just(42),
    Strategy<String>.just("hello"),
    Strategy<Bool>.just(true),
    Strategy<Double>.just(1.5),
    config: PropertyConfig(maxRuns: 1, seed: 1)
  ) { number, text, flag, decimal in
    #expect(number == 42)
    #expect(text == "hello")
    #expect(flag)
    #expect(decimal == 1.5)
  }
}

@Test("forAll supports async properties and a nonempty pack")
func variadicForAllAsync() async throws {
  try await forAll(
    Strategy<Int>.just(42),
    Strategy<String>.just("hello"),
    Strategy<Bool>.just(true),
    Strategy<Double>.just(1.5),
    Strategy<Int>.just(7),
    config: PropertyConfig(maxRuns: 1, seed: 1)
  ) { (x: Int, text: String, flag: Bool, val: Double, end: Int) async throws in
    #expect(x == 42)
    #expect(text == "hello")
    #expect(flag)
    #expect(val == 1.5)
    #expect(end == 7)
  }
}
