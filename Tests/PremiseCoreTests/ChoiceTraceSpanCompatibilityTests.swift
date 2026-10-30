import Foundation
import Testing
import PremiseCore

@Test("Span initializers preserve labels and Codable behavior")
func choiceTraceSpanInitializers() throws {
  let labeled = ChoiceTrace.Span(label: "example", start: 1, end: 2)
  let unlabeled = ChoiceTrace.Span(start: 1, end: 2)
  #expect(labeled.label == "example")
  #expect(unlabeled.label == nil)
  for span in [labeled, unlabeled] {
    let data = try JSONEncoder().encode(span)
    #expect(try JSONDecoder().decode(ChoiceTrace.Span.self, from: data) == span)
  }
}
