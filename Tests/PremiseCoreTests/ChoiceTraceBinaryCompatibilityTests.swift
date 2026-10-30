import Foundation
import PremiseCore
import Testing

@Test("ChoiceTrace binary format retains its stable byte representation")
func choiceTraceBinaryCompatibility() throws {
  let expected: [UInt8] = [
    0x50, 0x54, 0x52, 0x43, 0, 1,
    0, 0, 0, 4,
    0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 17,
    1, 0, 0, 0, 0, 0, 0, 0, 42,
    2, 1,
    3, 0, 0, 0, 3, 1, 2, 3,
    0, 0, 0, 1,
    1, 0, 0, 0, 7, 112, 97, 121, 108, 111, 97, 100,
    0, 0, 0, 1, 0, 0, 0, 4,
  ]
  let trace = ChoiceTrace(
    entries: [
      .bits(.init(count: 5, value: 17)), .integer(42), .boolean(true), .bytes([1, 2, 3]),
    ],
    spans: [.init(label: "payload", start: 1, end: 4)]
  )
  #expect(try Array(trace.binaryEncoded()) == expected)
  #expect(try ChoiceTrace(binaryData: Data(expected)) == trace)
}
