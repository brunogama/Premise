import Foundation
import Testing

@testable import ConjectureCore

@Test("ChoiceTrace records draws and round-trips")
func choiceTraceRecordsAndRoundTrips() throws {
  var data = ConjectureData(provider: PseudoRandomProvider(seed: 42, maxDraws: 16))

  let integer = data.drawInteger(in: 0...10)
  let boolean = data.drawBoolean()
  let bytes = data.drawBytes(count: 3)
  let spanValue = data.withSpan("payload") { spanData in
    spanData.drawInteger(in: 1...3)
  }

  let trace = data.snapshot()
  let encoded = try JSONEncoder().encode(trace)
  let decoded = try JSONDecoder().decode(ChoiceTrace.self, from: encoded)

  #expect(trace == decoded)
  #expect(trace.entries.count >= 4)
  #expect(integer >= 0)
  #expect(
    trace.entries.contains { entry in
      if case .integer = entry {
        return true
      }

      return false
    }
  )
  #expect(
    trace.entries.contains { entry in
      if case .boolean(let recorded) = entry {
        return recorded == boolean
      }

      return false
    }
  )
  #expect(bytes.count == 3)
  #expect(spanValue >= 1)
  #expect(trace.spans.count == 1)
  #expect(trace.spans.first?.label == "payload")
}

@Test("ConjectureData tracks active, exhausted, and interesting status")
func conjectureDataTracksStatusTransitions() {
  var data = ConjectureData(provider: PseudoRandomProvider(seed: 1, maxDraws: 1))

  _ = data.drawBoolean()
  #expect(data.status == .active)

  _ = data.drawBoolean()
  #expect(data.status == .exhausted)

  data.markInteresting()
  #expect(data.status == .interesting)
}
