import Testing

@testable import PremiseCore
@testable import PremiseTesting

private enum DataAwareError: Error, CustomStringConvertible {
  case failed

  var description: String { "data-aware failure" }
}

@Test("Data-aware forAll allows imperative draws")
func dataAwareForAllAllowsImperativeDraws() async throws {
  try await forAll(
    .integers(in: 0...3),
    config: PropertyConfig(maxRuns: 5, seed: 1)
  ) { value, data in
    let extra = try data.draw(.integers(in: 0...3))
    data.event(extra.isMultiple(of: 2) ? "extra-even" : "extra-odd")
    #expect((0...3).contains(value))
    #expect((0...3).contains(extra))
  }
}

@Test("Failure formatter includes statistics")
func formatterIncludesStatistics() {
  let propertyID = PropertyIdentity(fileID: "StatsTests", line: 7, strategyLabel: "integers")
  var stats = RunStatistics()
  stats.events = ["empty", "empty", "non-empty"]
  stats.notes = [RunNote(label: "length", value: "0")]
  stats.targetScore = 4
  let record = FailureRecord(
    propertyID: propertyID,
    trace: ChoiceTrace(),
    errorMessage: "boom",
    runCount: 1,
    shrinkCount: 0,
    seed: 1,
    statistics: stats
  )
  let report = RunReport(
    runCount: 1,
    events: ["empty": 2, "non-empty": 1],
    notes: stats.notes,
    maxTargetScore: 4,
    healthWarnings: [
      HealthWarning(
        check: .excessiveFiltering,
        message: "More than half of generated examples were rejected."
      )
    ]
  )
  let output = FailureFormatter.format(
    value: 0,
    record: record,
    propertyID: propertyID,
    report: report
  )
  #expect(output.contains("Events: empty=2, non-empty=1"))
  #expect(output.contains("Notes: length=0"))
  #expect(output.contains("Target score: 4.0"))
  #expect(output.contains("Health warnings: excessiveFiltering"))
}
