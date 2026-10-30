import PremiseCore
import PremiseDatabase

func persist(
  failure: StateMachineFailure,
  config: StateMachineConfig,
  database: FileBackedDatabase?
) async throws {
  let record = failureRecord(failure, config: config)
  if let database {
    try await database.save(record)
  }
  guard let directory = config.traceExportDirectory else { return }
  _ = try FailureTraceExporter.export(
    FailureTraceArtifact(
      record: record,
      valueDescription: failure.program.description
    ),
    to: directory
  )
}

private func failureRecord(
  _ failure: StateMachineFailure,
  config: StateMachineConfig
) -> FailureRecord {
  FailureRecord(
    propertyID: config.propertyID,
    trace: failure.replayTrace,
    errorMessage: failure.description,
    runCount: max(0, failure.exampleIndex + 1),
    shrinkCount: failure.shrinkCount,
    seed: failure.baseSeed,
    statistics: RunStatistics(
      notes: [RunNote(label: "program", value: failure.program.description)],
      events: [],
      targetScore: nil
    )
  )
}
