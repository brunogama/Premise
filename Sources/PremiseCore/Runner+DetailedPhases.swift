extension Runner {
  func runDetailedPhase(
    _ input: DetailedPhaseInput<Value>,
    report: inout RunReport,
    property: @escaping @Sendable (Value, inout PremiseData) throws -> Void
  ) -> ExecutionFailure<Value>? {
    let cases = input.cases
    switch input.phase {
    case .explicit:
      return explicitPhase(cases.examples, report: &report, property: property)
    case .replay:
      return replayPhase(cases.traces, report: &report, property: property)
    case .generate:
      return asFailure(runGeneratePhase(report: &report, property: property))
    case .target:
      return asFailure(runTargetPhase(report: &report, property: property))
    case .shrink:
      return nil
    }
  }

  func runDetailedPhaseAsync(
    _ input: DetailedPhaseInput<Value>,
    report: inout RunReport,
    property body: @escaping @Sendable (Value) async throws -> Void
  ) async -> ExecutionFailure<Value>? {
    let examples = input.cases.examples
    let traces = input.cases.traces
    switch input.phase {
    case .explicit:
      return await explicitPhaseAsync(examples, report: &report, property: body)
    case .replay:
      return await replayPhaseAsync(traces, report: &report, property: body)
    case .generate:
      return asFailure(
        await runGeneratePhaseAsync(report: &report, property: body)
      )
    case .target:
      return asFailure(
        await runTargetPhaseAsync(report: &report, property: body)
      )
    case .shrink:
      return nil
    }
  }

  func finishDetailed(
    report: RunReport,
    failure: ExecutionFailure<Value>?
  ) -> DetailedRunResult<Value> {
    var report = report
    report.applyHealthChecks(
      enabledChecks: config.healthChecks,
      maxRuns: config.maxRuns
    )
    if let failure {
      return finish(
        .failure(failure.record, value: failure.value, report: report)
      )
    }
    return finish(.passed(report))
  }

  private func asFailure(
    _ result: (record: FailureRecord, value: Value)?
  ) -> ExecutionFailure<Value>? {
    guard let result else { return nil }
    return ExecutionFailure(record: result.record, value: result.value)
  }

  private func explicitPhase(
    _ examples: [ExplicitExample<Value>],
    report: inout RunReport,
    property: @Sendable (Value, inout PremiseData) throws -> Void
  ) -> ExecutionFailure<Value>? {
    for example in examples {
      if let failure = executeExplicit(
        example,
        property: property,
        report: &report
      ) {
        report.recordFailure(failure.record, phase: .explicit)
        return failure
      }
    }
    return nil
  }

  private func explicitPhaseAsync(
    _ examples: [ExplicitExample<Value>],
    report: inout RunReport,
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> ExecutionFailure<Value>? {
    for example in examples {
      if let failure = await executeExplicitAsync(
        example,
        property: property,
        report: &report
      ) {
        report.recordFailure(failure.record, phase: .explicit)
        return failure
      }
    }
    return nil
  }

  private func replayPhase(
    _ traces: [ChoiceTrace],
    report: inout RunReport,
    property: @escaping @Sendable (Value, inout PremiseData) throws -> Void
  ) -> ExecutionFailure<Value>? {
    guard config.replayEnabled else { return nil }
    for trace in traces {
      switch executeAttempt(trace: trace, property: property) {
      case .passed(let statistics, _):
        report.recordPhase(.replay)
        report.merge(statistics)
      case .rejected(let kind, let statistics, _):
        report.recordRejected(kind)
        report.merge(statistics)
      case .failure(let failure):
        return replayFailure(failure, report: &report, property: property)
      }
    }
    return nil
  }

  private func replayPhaseAsync(
    _ traces: [ChoiceTrace],
    report: inout RunReport,
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> ExecutionFailure<Value>? {
    guard config.replayEnabled else { return nil }
    for trace in traces {
      switch await executeAttemptAsync(trace: trace, property: property) {
      case .passed(let statistics, _):
        report.recordPhase(.replay)
        report.merge(statistics)
      case .rejected(let kind, let statistics, _):
        report.recordRejected(kind)
        report.merge(statistics)
      case .failure(let failure):
        return await replayFailureAsync(
          failure,
          report: &report,
          property: property
        )
      }
    }
    return nil
  }

  private func replayFailure(
    _ failure: ExecutionFailure<Value>,
    report: inout RunReport,
    property: @escaping @Sendable (Value, inout PremiseData) throws -> Void
  ) -> ExecutionFailure<Value> {
    let minimized = minimizeIfNeeded(
      failure: failure,
      context: .from(
        failure: failure,
        runCount: 1,
        seed: failure.record.seed,
        discovery: .knownFailure
      ),
      property: property
    )
    recordReplayFailure(minimized.record, report: &report)
    return ExecutionFailure(record: minimized.record, value: minimized.value)
  }

  private func replayFailureAsync(
    _ failure: ExecutionFailure<Value>,
    report: inout RunReport,
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> ExecutionFailure<Value> {
    let minimized = await minimizeIfNeeded(
      failure: failure,
      context: .from(
        failure: failure,
        runCount: 1,
        seed: failure.record.seed,
        discovery: .knownFailure
      ),
      property: property
    )
    recordReplayFailure(minimized.record, report: &report)
    return ExecutionFailure(record: minimized.record, value: minimized.value)
  }

  private func recordReplayFailure(
    _ record: FailureRecord,
    report: inout RunReport
  ) {
    report.recordPhase(.replay)
    report.merge(record.statistics)
    report.recordFailure(record, phase: .replay)
  }
}
