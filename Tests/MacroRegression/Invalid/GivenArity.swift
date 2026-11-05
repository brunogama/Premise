import PremiseCore
import PremiseMacros
import PremiseStrategies
import PremiseTesting
import Testing

@given(
  Strategy<Int>.integers(in: 1...1),
  Strategy<Int>.integers(in: 2...2)
)
func mismatchedArity(value: Int) {
  #expect(value == 1)
}
