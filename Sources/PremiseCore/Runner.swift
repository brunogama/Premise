import Foundation

/// Executes Premise strategies against property closures.
public struct Runner<Value: Sendable>: Sendable {
  /// Strategy used to generate and shrink values.
  public let strategy: Strategy<Value>

  /// Execution configuration for this runner.
  public let config: PropertyConfig

  /// Stable identity used for persistence and diagnostics.
  public let propertyID: PropertyIdentity

  /// Creates a property runner.
  public init(
    strategy: Strategy<Value>,
    config: PropertyConfig = .default,
    propertyID: PropertyIdentity = PropertyIdentity(
      fileID: "unknown",
      line: 0,
      strategyLabel: "unknown"
    )
  ) {
    self.strategy = strategy
    self.config = config
    self.propertyID = propertyID
  }

}

extension Runner {
  // MARK: - Public run

  /// Executes a data-aware property and returns diagnostics-rich results.
  public func runDetailed(
    explicitExamples: [Value] = [],
    examples: [ExplicitExample<Value>] = [],
    _ property: @escaping @Sendable (Value, inout PremiseData) throws -> Void,
    replayTraces: [ChoiceTrace] = []
  ) async -> DetailedRunResult<Value> {
    var report = RunReport()
    let allExamples = explicitExamples.map { ExplicitExample($0) } + examples
    for phase in config.phases {
      if let failure = runDetailedPhase(
        phase,
        examples: allExamples,
        traces: replayTraces,
        report: &report,
        property: property
      ) {
        return finishDetailed(report: report, failure: failure)
      }
    }
    return finishDetailed(report: report, failure: nil)
  }

  /// Executes a property and returns diagnostics-rich results.
  public func runDetailed(
    explicitExamples: [Value] = [],
    examples: [ExplicitExample<Value>] = [],
    _ property: @escaping @Sendable (Value) throws -> Void,
    replayTraces: [ChoiceTrace] = []
  ) async -> DetailedRunResult<Value> {
    await runDetailed(
      explicitExamples: explicitExamples,
      examples: examples,
      { value, _ in
        try property(value)
      },
      replayTraces: replayTraces
    )
  }

  /// Executes an async property and returns diagnostics-rich results.
  public func runDetailed(
    explicitExamples: [Value] = [],
    examples: [ExplicitExample<Value>] = [],
    _ property: @escaping @Sendable (Value) async throws -> Void,
    replayTraces: [ChoiceTrace] = []
  ) async -> DetailedRunResult<Value> {
    var report = RunReport()
    let allExamples = explicitExamples.map { ExplicitExample($0) } + examples
    for phase in config.phases {
      if let failure = await runDetailedPhaseAsync(
        phase,
        examples: allExamples,
        traces: replayTraces,
        report: &report,
        property: property
      ) {
        return finishDetailed(report: report, failure: failure)
      }
    }
    return finishDetailed(report: report, failure: nil)
  }

  /// Executes the property, replaying any stored traces first, then running
  /// fresh generations.
  ///
  /// The first failure found is minimised via ``ShrinkMachine`` before being
  /// returned.
  ///
  /// When `config.seed` is `nil` a cryptographically-random base seed is
  /// chosen for this invocation and embedded in the returned ``FailureRecord``
  /// so the exact run can be reproduced:
  ///
  /// ```swift
  /// // Reproduce a failure:
  /// let config = PropertyConfig(seed: record.seed)
  /// ```
  public func run(
    _ property: @escaping @Sendable (Value) throws -> Void,
    replayTraces: [ChoiceTrace] = []
  ) async -> RunResult<Value> {
    if let result = legacyReplay(replayTraces, property: property) {
      return result
    }
    return legacyGenerate(property: property)
  }

  /// Executes an async property, replaying stored traces first, then running
  /// fresh generations.
  ///
  /// This overload mirrors the synchronous runner while allowing property
  /// bodies to await application code directly.
  public func run(
    _ property: @escaping @Sendable (Value) async throws -> Void,
    replayTraces: [ChoiceTrace] = []
  ) async -> RunResult<Value> {
    if let result = await legacyReplayAsync(replayTraces, property: property) {
      return result
    }
    return await legacyGenerateAsync(property: property)
  }

  // MARK: - Replay

  /// Returns `true` if replaying `trace` against `property` still fails.
  public func replay(
    _ trace: ChoiceTrace,
    property: @Sendable (Value) throws -> Void
  ) -> Bool {
    executeSingle(trace: trace, property: property) != nil
  }

  /// Returns `true` if replaying `trace` against a data-aware property still fails.
  public func replay(
    _ trace: ChoiceTrace,
    property: @Sendable (Value, inout PremiseData) throws -> Void
  ) -> Bool {
    executeSingle(trace: trace, property: property) != nil
  }

  /// Returns `true` if replaying `trace` against an async property still fails.
  public func replay(
    _ trace: ChoiceTrace,
    property: @escaping @Sendable (Value) async throws -> Void
  ) async -> Bool {
    await executeSingleAsync(trace: trace, property: property) != nil
  }

  // MARK: - Internal execution helpers

  func makeBaseSeed() -> UInt64 {
    if let seed = config.seed {
      return seed
    }
    if config.derandomize {
      return stableSeed(for: propertyID)
    }
    return UInt64.random(in: .min ... .max)
  }

  private func stableSeed(for id: PropertyIdentity) -> UInt64 {
    let input = [
      id.fileID,
      String(id.line),
      id.strategyLabel,
      id.functionName ?? "",
    ].joined(separator: "#")
    var hash: UInt64 = 1_469_598_103_934_665_603
    for byte in input.utf8 {
      hash ^= UInt64(byte)
      hash &*= 1_099_511_628_211
    }
    return hash
  }

  func deadlineFailure(since start: Date) -> String? {
    guard let deadline = config.perExampleDeadlineSeconds else {
      return nil
    }
    let elapsed = Date().timeIntervalSince(start)
    guard elapsed > deadline else {
      return nil
    }
    return String(
      describing: PropertyDeadlineExceeded(
        elapsedSeconds: elapsed,
        deadlineSeconds: deadline
      )
    )
  }

  func makeFailure(
    value: Value,
    data: inout PremiseData,
    errorMessage: String,
    runCount: Int
  ) -> ExecutionFailure<Value> {
    let record = FailureRecord(
      propertyID: propertyID,
      trace: data.snapshot(),
      errorMessage: errorMessage,
      runCount: runCount,
      shrinkCount: 0,
      statistics: data.statistics
    )
    return ExecutionFailure(record: record, value: value)
  }

  func expectedFailureIfNeeded(
    example: ExplicitExample<Value>,
    data: inout PremiseData
  ) -> ExecutionFailure<Value>? {
    guard case .expectedToFail(let reason) = example.expectation else {
      return nil
    }
    let suffix = reason.map { $0.isEmpty ? "" : ": \($0)" } ?? ""
    return makeFailure(
      value: example.value,
      data: &data,
      errorMessage: "Expected explicit example to fail\(suffix)",
      runCount: 0
    )
  }

  func isExpectedToFail(_ example: ExplicitExample<Value>) -> Bool {
    if case .expectedToFail = example.expectation {
      return true
    }
    return false
  }

  func finish(
    _ result: DetailedRunResult<Value>
  ) -> DetailedRunResult<Value> {
    emitJSONLineIfNeeded(for: result)
    return result
  }

  private func emitJSONLineIfNeeded(for result: DetailedRunResult<Value>) {
    guard let outputURL = config.jsonlOutputURL else {
      return
    }
    let event = RunJSONLEvent(propertyID: propertyID, result: result)
    try? RunJSONLWriter.append(event, to: outputURL)
  }
}
