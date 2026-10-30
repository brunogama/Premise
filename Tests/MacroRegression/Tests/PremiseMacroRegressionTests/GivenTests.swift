import PremiseCore
import PremiseMacros
import PremiseStrategies
import PremiseTesting
import Testing

@given(Strategy<Int>.integers(in: 1...1))
func oneValue(value: Int) {
  #expect(value == 1)
}

@given(
  Strategy<Int>.integers(in: 1...1),
  Strategy<Int>.integers(in: 2...2),
  Strategy<Int>.integers(in: 3...3),
  Strategy<Int>.integers(in: 4...4)
)
func fourValues(first: Int, second: Int, third: Int, fourth: Int) {
  #expect(first == 1)
  #expect(second == 2)
  #expect(third == 3)
  #expect(fourth == 4)
}

private let premiseGeneratedValues = 123

@given(
  Strategy<Int>.integers(in: 1...1),
  Strategy<Int>.integers(in: 2...2),
  Strategy<Int>.integers(in: 3...3),
  Strategy<Int>.integers(in: 4...4)
)
func avoidsCapturingGlobals(first: Int, second: Int, third: Int, fourth: Int) {
  #expect(premiseGeneratedValues == 123)
  #expect(first + second + third + fourth == 10)
}

@given(
  Strategy<Int>.integers(in: 1...1),
  Strategy<Int>.integers(in: 2...2),
  Strategy<Int>.integers(in: 3...3)
)
func threeValues(first: Int, second: Int, third: Int) {
  #expect(first + second + third == 6)
}

@given(Strategy<Int>.integers(in: 1...1))
func `repeat`(value: Int) {
  #expect(value == 1)
}

@Suite struct ExistingSuite {
  @given(Strategy<Int>.integers(in: 1...1))
  func nested(value: Int) async throws {
    #expect(value == 1)
  }
}
