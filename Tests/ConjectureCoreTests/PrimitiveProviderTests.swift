import Testing

@testable import ConjectureCore

private struct DrawSample: Equatable {
  var firstInteger: Int
  var flag: Bool
  var payload: [UInt8]
  var trailingInteger: Int
}

@Test("Equal seeds produce equal traces")
func equalSeedsProduceEqualTraces() {
  var lhs = ConjectureData(provider: PseudoRandomProvider(seed: 7, maxDraws: 32))
  var rhs = ConjectureData(provider: PseudoRandomProvider(seed: 7, maxDraws: 32))

  #expect(drawSample(using: &lhs) == drawSample(using: &rhs))
  #expect(lhs.snapshot() == rhs.snapshot())
}

@Test("ReplayProvider reproduces the same draw sequence")
func replayProviderReproducesSequence() {
  var source = ConjectureData(provider: PseudoRandomProvider(seed: 21, maxDraws: 32))
  let original = drawSample(using: &source)
  let trace = source.snapshot()

  var replay = ConjectureData(provider: ReplayProvider(trace: trace))
  let replayed = drawSample(using: &replay)

  #expect(replayed == original)
  #expect(replay.snapshot() == trace)
  #expect(replay.status == .active)
}

private func drawSample(using data: inout ConjectureData) -> DrawSample {
  let firstInteger = data.drawInteger(in: 0...50)
  let flag = data.drawBoolean()
  let payload = data.withSpan("payload") { spanData in
    spanData.drawBytes(count: 3)
  }
  let trailingInteger = data.drawInteger(in: 10...20)

  return DrawSample(
    firstInteger: firstInteger,
    flag: flag,
    payload: payload,
    trailingInteger: trailingInteger
  )
}
