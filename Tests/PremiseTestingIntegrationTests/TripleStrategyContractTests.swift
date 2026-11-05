import PremiseCore
import PremiseStrategies
import Testing

@testable import PremiseTesting

@Test("triple strategies preserve labels, draw order, and shrink order")
func tripleStrategyContract() throws {
  let first = component("first", value: 10)
  let second = component("second", value: 20)
  let third = component("third", value: 30)
  let combined = combinedStrategy(first, second, third)
  let zipped = zip(first, second, third)

  #expect(combined.label == "(first, second, third)")
  #expect(zipped.label == "zip(first, second, third)")
  for strategy in [combined, zipped] {
    var data = PremiseData(provider: PseudoRandomProvider(seed: 1, maxDraws: 8))
    let value = try strategy.draw(&data)
    #expect([value.0, value.1, value.2] == [10, 20, 30])
    #expect(data.statistics.notes.map(\.label) == ["first", "second", "third"])
    let shrinks = strategy.shrink(value).map { [$0.0, $0.1, $0.2] }
    #expect(
      shrinks == [
        [9, 20, 30], [8, 20, 30], [10, 19, 30],
        [10, 18, 30], [10, 20, 29], [10, 20, 28],
      ]
    )
  }
}

private func component(_ label: String, value: Int) -> Strategy<Int> {
  Strategy(
    label: label,
    draw: { data in
      data.note(label, value: value)
      return value
    },
    shrink: { [$0 - 1, $0 - 2] }
  )
}
