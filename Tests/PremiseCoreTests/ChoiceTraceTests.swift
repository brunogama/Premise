import Foundation
import Testing

@testable import PremiseCore

@Test("ChoiceTrace records draws and round-trips")
func choiceTraceRecordsAndRoundTrips() throws {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 42, maxDraws: 16))

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

@Test("ChoiceTrace stable binary blobs round-trip")
func choiceTraceStableBinaryBlobRoundTrips() throws {
  let trace = ChoiceTrace(
    entries: [
      .bits(ChoiceTrace.BitEntry(count: 5, value: 17)),
      .integer(42),
      .boolean(true),
      .bytes([1, 2, 3]),
    ],
    spans: [ChoiceTrace.Span(label: "payload", start: 1, end: 4)]
  )

  let data = try trace.binaryEncoded()
  let decoded = try ChoiceTrace(binaryData: data)
  let blob = try trace.reproductionBlob()
  let blobDecoded = try ChoiceTrace.decodeReproductionBlob(blob)

  #expect(Array(data.prefix(4)) == ChoiceTrace.binaryMagic)
  #expect(decoded == trace)
  #expect(blob.hasPrefix(ChoiceTrace.reproductionBlobPrefix))
  #expect(blobDecoded == trace)
}

@Test("ChoiceTrace blob decoder rejects unsupported versions")
func choiceTraceBlobDecoderRejectsUnsupportedVersions() throws {
  let trace = ChoiceTrace(entries: [.integer(1)])
  var data = try trace.binaryEncoded()
  data[4] = 0
  data[5] = 2

  #expect(throws: ChoiceTraceBlobError.self) {
    try ChoiceTrace(binaryData: data)
  }

  do {
    _ = try ChoiceTrace(binaryData: data)
  } catch let error as ChoiceTraceBlobError {
    #expect(error == .unsupportedVersion(found: 2, supported: 1...1))
  }
}

@Test("PremiseData tracks active, exhausted, and interesting status")
func premiseDataTracksStatusTransitions() {
  var data = PremiseData(provider: PseudoRandomProvider(seed: 1, maxDraws: 1))

  _ = data.drawBoolean()
  #expect(data.status == .active)

  _ = data.drawBoolean()
  #expect(data.status == .exhausted)

  data.markInteresting()
  #expect(data.status == .interesting)
}
