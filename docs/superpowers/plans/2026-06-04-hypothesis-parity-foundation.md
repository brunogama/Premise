# Hypothesis Parity Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first Hypothesis-parity layer that Premise is still missing: explicit examples and phase control, first-class run reports/statistics/health checks, robust imperative draw access, scoped type-driven strategy derivation, and a rule-based stateful testing DSL.

**Architecture:** Keep `PremiseCore` macro-free and storage-neutral. Add opt-in APIs that preserve the existing `Runner.run` and `forAll` surfaces, then let adapters use the richer detailed execution path for diagnostics. Stateful testing stays in `PremiseTesting` because it is a test-framework-facing convenience over core strategies and runner semantics.

**Tech Stack:** Swift 6.2, SwiftPM, `PremiseCore`, `PremiseStrategies`, `PremiseTesting`, `PremiseDatabase`, swift-testing tests.

---

## Scope Check

This plan intentionally covers the Hypothesis features that share the same core engine path:

- explicit examples and phase selection
- run statistics, health warnings, and event/target output
- imperative drawing through `PremiseData`
- scoped type-driven strategy derivation without global mutable state
- rule-based stateful testing with rules, preconditions, invariants, and bundles

Do not add these independent subsystems in this plan:

- Ghostwriter CLI/test-generation. Create a separate plan for an executable target such as `PremiseGhostwriter`.
- External fuzzer bridge. Create a separate plan for a stable byte-buffer interface similar to `fuzz_one_input`.
- Large strategy catalog extras such as regex strings, IP addresses, URL domains, Decimal/Fraction equivalents, and timezone-heavy date/time strategies. Create a separate catalog plan because each strategy needs dedicated shrinking tests.

## File Structure

- Create `Sources/PremiseCore/PropertyPhase.swift`: phase enum and membership helpers.
- Create `Sources/PremiseCore/RunReport.swift`: detailed execution result, per-run observations, aggregate statistics, and health warnings.
- Modify `Sources/PremiseCore/PropertyConfig.swift`: phase and health-check settings plus builder methods.
- Modify `Sources/PremiseCore/RunStatistics.swift`: make statistics codable and add a memberwise initializer used by formatters.
- Modify `Sources/PremiseCore/PremiseCore.swift`: add optional statistics to `FailureRecord`.
- Modify `Sources/PremiseCore/Runner.swift`: add `runDetailed` overloads, explicit-example execution, data-aware properties, health aggregation, and compatibility wrappers for existing `run`.
- Modify `Sources/PremiseTesting/FailureFormatter.swift`: include health warnings, notes, events, and target scores.
- Modify `Sources/PremiseTesting/ForAll.swift`: route through detailed execution and remove the manual data-aware loop.
- Create `Sources/PremiseStrategies/StrategyDerivation.swift`: scoped registry and `StrategyProviding` protocol.
- Create `Sources/PremiseTesting/RuleBasedStateMachine.swift`: state-machine DSL.
- Modify `Package.swift`: no new product for this slice; add files to existing targets automatically.
- Create `Tests/PremiseCoreTests/PhaseAndReportTests.swift`: core phase/report tests.
- Create `Tests/PremiseTestingIntegrationTests/DataAwareForAllTests.swift`: adapter tests for `PremiseData` access.
- Create `Tests/PremiseStrategiesTests/StrategyDerivationTests.swift`: scoped strategy derivation tests.
- Create `Tests/PremiseTestingIntegrationTests/RuleBasedStateMachineTests.swift`: stateful DSL tests.
- Modify `README.md`: add a short “Hypothesis parity APIs” section.
- Modify `Sources/PremiseCore/Documentation.docc/Articles/StrategyCatalog.md`: mention derivation.
- Create `Sources/PremiseCore/Documentation.docc/Articles/StatefulRuleMachines.md`: stateful testing docs.

## Task 1: Add Phases, Explicit Examples, and Detailed Run Reports

**Files:**
- Create: `Sources/PremiseCore/PropertyPhase.swift`
- Create: `Sources/PremiseCore/RunReport.swift`
- Modify: `Sources/PremiseCore/PropertyConfig.swift`
- Modify: `Sources/PremiseCore/RunStatistics.swift`
- Modify: `Sources/PremiseCore/PremiseCore.swift`
- Modify: `Sources/PremiseCore/Runner.swift`
- Test: `Tests/PremiseCoreTests/PhaseAndReportTests.swift`

- [ ] **Step 1: Write failing phase/report tests**

Create `Tests/PremiseCoreTests/PhaseAndReportTests.swift`:

```swift
import Testing

@testable import PremiseCore

private enum PhaseTestError: Error, CustomStringConvertible {
  case failed(String)
  var description: String {
    switch self {
    case .failed(let message): return message
    }
  }
}

@Test("Explicit examples run before generated examples")
func explicitExamplesRunBeforeGeneration() async {
  let strategy = Strategy<Int>.just(99)
  let runner = Runner(
    strategy: strategy,
    config: PropertyConfig(maxRuns: 10, seed: 1)
  )

  let result = await runner.runDetailed(
    explicitExamples: [3]
  ) { value in
    if value == 3 {
      throw PhaseTestError.failed("explicit example failed")
    }
  }

  guard case .failure(let record, let value, let report) = result else {
    Issue.record("Expected explicit example failure")
    return
  }

  #expect(value == 3)
  #expect(record.runCount == 0)
  #expect(report.phaseCounts[.explicit] == 1)
  #expect(report.phaseCounts[.generate] == nil)
}

@Test("Generation phase can be disabled")
func generationPhaseCanBeDisabled() async {
  let strategy = Strategy<Int>.just(99)
  let config = PropertyConfig(maxRuns: 10, seed: 1)
    .phases([.explicit])
  let runner = Runner(strategy: strategy, config: config)

  let result = await runner.runDetailed(explicitExamples: [1, 2]) { value in
    #expect(value == 1 || value == 2)
  }

  guard case .passed(let report) = result else {
    Issue.record("Expected pass with explicit-only phases")
    return
  }

  #expect(report.runCount == 2)
  #expect(report.phaseCounts[.explicit] == 2)
  #expect(report.phaseCounts[.generate] == nil)
}

@Test("Run report aggregates events notes and target scores")
func runReportAggregatesStatistics() async {
  let strategy = Strategy<Int>.integers(in: 0...2)
  let runner = Runner(
    strategy: strategy,
    config: PropertyConfig(maxRuns: 3, seed: 1)
  )

  let result = await runner.runDetailed { value, data in
    data.event(value.isMultiple(of: 2) ? "even" : "odd")
    data.note("value", value: value)
    data.target(Double(value), label: "magnitude")
  }

  guard case .passed(let report) = result else {
    Issue.record("Expected passing detailed run")
    return
  }

  #expect(report.runCount == 3)
  #expect(report.events.values.reduce(0, +) == 3)
  #expect(report.notes.count == 3)
  #expect(report.maxTargetScore != nil)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter PhaseAndReportTests
```

Expected: FAIL with errors for missing `runDetailed`, `PropertyPhase`, `RunReport`, `phases`, and data-aware `Runner.runDetailed`.

- [ ] **Step 3: Add phase enum**

Create `Sources/PremiseCore/PropertyPhase.swift`:

```swift
/// Logical execution phases for a property run.
public enum PropertyPhase: String, Sendable, Codable, Hashable, CaseIterable {
  /// Run caller-provided examples before generated exploration.
  case explicit

  /// Replay persisted failures from a local database or committed corpus.
  case replay

  /// Generate fresh pseudo-random examples.
  case generate

  /// Minimize a failing example.
  case shrink
}

public extension Array where Element == PropertyPhase {
  /// Default Premise phase order.
  static let premiseDefault: [PropertyPhase] = [
    .explicit,
    .replay,
    .generate,
    .shrink,
  ]

  /// Returns true when the phase is enabled.
  func includes(_ phase: PropertyPhase) -> Bool {
    contains(phase)
  }
}
```

- [ ] **Step 4: Add detailed run report types**

Create `Sources/PremiseCore/RunReport.swift`:

```swift
/// Runtime health checks that can produce non-fatal warnings.
public enum HealthCheck: String, Sendable, Codable, Hashable, CaseIterable {
  case excessiveFiltering
  case slowGeneration
  case emptySearch
}

/// A non-fatal warning about property execution quality.
public struct HealthWarning: Sendable, Codable, Equatable {
  public let check: HealthCheck
  public let message: String

  public init(check: HealthCheck, message: String) {
    self.check = check
    self.message = message
  }
}

/// Aggregated observations from all attempted examples.
public struct RunReport: Sendable, Codable, Equatable {
  public var runCount: Int
  public var rejectedCount: Int
  public var phaseCounts: [PropertyPhase: Int]
  public var events: [String: Int]
  public var notes: [RunNote]
  public var maxTargetScore: Double?
  public var healthWarnings: [HealthWarning]

  public init(
    runCount: Int = 0,
    rejectedCount: Int = 0,
    phaseCounts: [PropertyPhase: Int] = [:],
    events: [String: Int] = [:],
    notes: [RunNote] = [],
    maxTargetScore: Double? = nil,
    healthWarnings: [HealthWarning] = []
  ) {
    self.runCount = runCount
    self.rejectedCount = rejectedCount
    self.phaseCounts = phaseCounts
    self.events = events
    self.notes = notes
    self.maxTargetScore = maxTargetScore
    self.healthWarnings = healthWarnings
  }

  public mutating func recordPhase(_ phase: PropertyPhase) {
    phaseCounts[phase, default: 0] += 1
    runCount += 1
  }

  public mutating func recordRejected() {
    rejectedCount += 1
  }

  public mutating func merge(_ statistics: RunStatistics) {
    for event in statistics.events {
      events[event, default: 0] += 1
    }
    notes.append(contentsOf: statistics.notes)
    if let score = statistics.targetScore {
      maxTargetScore = max(maxTargetScore ?? score, score)
    }
  }

  public mutating func applyHealthChecks(
    enabledChecks: [HealthCheck],
    maxRuns: Int
  ) {
    guard maxRuns > 0 else { return }

    if enabledChecks.contains(.emptySearch), runCount == 0 {
      healthWarnings.append(
        HealthWarning(
          check: .emptySearch,
          message: "No valid examples were executed."
        )
      )
    }

    if enabledChecks.contains(.excessiveFiltering) {
      let attempts = runCount + rejectedCount
      if attempts >= 20, rejectedCount * 2 > attempts {
        healthWarnings.append(
          HealthWarning(
            check: .excessiveFiltering,
            message: "More than half of generated examples were rejected."
          )
        )
      }
    }
  }
}

/// Detailed result used by adapters that need diagnostics beyond pass/fail.
public enum DetailedRunResult<Value: Sendable>: Sendable {
  case passed(RunReport)
  case failure(FailureRecord, value: Value, report: RunReport)
}

public extension DetailedRunResult {
  var compact: RunResult<Value> {
    switch self {
    case .passed(let report):
      return .passed(runs: report.runCount)
    case .failure(let record, value: let value, report: _):
      return .failure(record, value: value)
    }
  }
}
```

- [ ] **Step 5: Extend PropertyConfig**

Modify `Sources/PremiseCore/PropertyConfig.swift` by adding properties:

```swift
  public var phases: [PropertyPhase]
  public var healthChecks: [HealthCheck]
```

Update the initializer signature:

```swift
    traceExportDirectory: URL? = nil,
    timeoutSeconds: Double? = nil,
    phases: [PropertyPhase] = .premiseDefault,
    healthChecks: [HealthCheck] = HealthCheck.allCases
```

Set the properties in the initializer:

```swift
    self.phases = phases
    self.healthChecks = healthChecks
```

Add builder methods at the end of the chainable builder section:

```swift
  /// Selects the execution phases and their order.
  public func phases(_ phases: [PropertyPhase]) -> Self {
    var copy = self
    copy.phases = phases
    return copy
  }

  /// Selects non-fatal health checks.
  public func healthChecks(_ checks: [HealthCheck]) -> Self {
    var copy = self
    copy.healthChecks = checks
    return copy
  }
```

- [ ] **Step 6: Add statistics to FailureRecord**

Modify `Sources/PremiseCore/RunStatistics.swift` so persisted `FailureRecord`
can encode statistics:

```swift
public struct RunStatistics: Sendable, Equatable, Codable {
```

Add this initializer below the existing empty initializer:

```swift
  public init(notes: [RunNote], events: [String], targetScore: Double?) {
    self.notes = notes
    self.events = events
    self.targetScore = targetScore
  }
```

Modify `Sources/PremiseCore/PremiseCore.swift`.

Add a stored property:

```swift
  /// Observations from the run that produced the minimized failure.
  public var statistics: RunStatistics
```

Update `FailureRecord.init`:

```swift
    seed: UInt64? = nil,
    discovery: FailureDiscovery = .newFailure,
    statistics: RunStatistics = RunStatistics()
```

Set it:

```swift
    self.statistics = statistics
```

- [ ] **Step 7: Add detailed runner APIs**

Modify `Sources/PremiseCore/Runner.swift`.

Add this public data-aware overload near the existing `run` methods:

```swift
  public func runDetailed(
    explicitExamples: [Value] = [],
    _ property: @escaping @Sendable (Value, inout PremiseData) throws -> Void,
    replayTraces: [ChoiceTrace] = []
  ) async -> DetailedRunResult<Value> {
    var report = RunReport()

    if config.phases.includes(.explicit) {
      for example in explicitExamples {
        if let failure = executeExplicit(
          example,
          property: property,
          report: &report
        ) {
          return .failure(failure.record, value: failure.value, report: report)
        }
      }
    }

    if config.phases.includes(.replay), config.replayEnabled {
      for trace in replayTraces {
        if let failure = executeSingle(trace: trace, property: property) {
          let minimized = minimizeIfNeeded(
            failure: failure,
            runCount: 1,
            property: property,
            seed: failure.record.seed,
            discovery: .knownFailure
          )
          report.recordPhase(.replay)
          report.merge(minimized.record.statistics)
          return .failure(minimized.record, value: minimized.value, report: report)
        }
      }
    }

    if config.phases.includes(.generate) {
      let baseSeed = config.seed ?? UInt64.random(in: .min ... .max)
      let deadline = config.timeoutSeconds.map { Date(timeIntervalSinceNow: $0) }

      for index in 0..<config.maxRuns {
        if let deadline, Date() > deadline { break }

        let provider = PseudoRandomProvider(
          seed: baseSeed &+ UInt64(index),
          maxDraws: config.maxDrawsPerRun
        )
        if let failure = executeSingle(provider: provider, property: property) {
          let minimized = minimizeIfNeeded(
            failure: failure,
            runCount: index + 1,
            property: property,
            seed: baseSeed,
            discovery: .newFailure
          )
          report.recordPhase(.generate)
          report.merge(minimized.record.statistics)
          report.applyHealthChecks(enabledChecks: config.healthChecks, maxRuns: config.maxRuns)
          return .failure(minimized.record, value: minimized.value, report: report)
        }

        report.recordPhase(.generate)
      }
    }

    report.applyHealthChecks(enabledChecks: config.healthChecks, maxRuns: config.maxRuns)
    return .passed(report)
  }

  public func runDetailed(
    explicitExamples: [Value] = [],
    _ property: @escaping @Sendable (Value) throws -> Void,
    replayTraces: [ChoiceTrace] = []
  ) async -> DetailedRunResult<Value> {
    await runDetailed(explicitExamples: explicitExamples, { value, _ in
      try property(value)
    }, replayTraces: replayTraces)
  }
```

Add private helpers before `ExecutionFailure`:

```swift
  private func executeExplicit(
    _ value: Value,
    property: @Sendable (Value, inout PremiseData) throws -> Void,
    report: inout RunReport
  ) -> ExecutionFailure<Value>? {
    var data = PremiseData(provider: PseudoRandomProvider(seed: 0, maxDraws: config.maxDrawsPerRun))
    report.recordPhase(.explicit)
    do {
      try property(value, &data)
      report.merge(data.statistics)
      return nil
    } catch {
      let record = FailureRecord(
        propertyID: propertyID,
        trace: data.snapshot(),
        errorMessage: String(describing: error),
        runCount: 0,
        shrinkCount: 0,
        statistics: data.statistics
      )
      report.merge(data.statistics)
      return ExecutionFailure(record: record, value: value)
    }
  }

  private func minimizeIfNeeded(
    failure: ExecutionFailure<Value>,
    runCount: Int,
    property: @escaping @Sendable (Value, inout PremiseData) throws -> Void,
    seed: UInt64?,
    discovery: FailureDiscovery
  ) -> (record: FailureRecord, value: Value) {
    guard config.phases.includes(.shrink) else {
      var record = failure.record
      record.runCount = runCount
      record.seed = seed
      record.discovery = discovery
      return (record, failure.value)
    }

    return minimizeTrace(
      initialTrace: failure.record.trace,
      errorMessage: failure.record.errorMessage,
      initialValue: failure.value,
      runCount: runCount,
      property: { value in
        var data = PremiseData(provider: ReplayProvider(trace: failure.record.trace))
        try property(value, &data)
      },
      seed: seed,
      discovery: discovery
    )
  }
```

Update existing `run` compatibility wrappers to delegate to detailed execution:

```swift
  public func run(
    _ property: @escaping @Sendable (Value) throws -> Void,
    replayTraces: [ChoiceTrace] = []
  ) async -> RunResult<Value> {
    await runDetailed(property, replayTraces: replayTraces).compact
  }
```

Update `executeSingle(provider:property:)` to accept data-aware properties and merge statistics into `FailureRecord`:

```swift
  func executeSingle(
    provider: some PrimitiveProvider,
    property: @Sendable (Value, inout PremiseData) throws -> Void
  ) -> ExecutionFailure<Value>? {
    var data = PremiseData(provider: provider)

    let drawnValue: Value
    do {
      drawnValue = try strategy.draw(&data)
    } catch {
      return nil
    }

    do {
      try property(drawnValue, &data)
      return nil
    } catch {
      let record = FailureRecord(
        propertyID: propertyID,
        trace: data.snapshot(),
        errorMessage: String(describing: error),
        runCount: 1,
        shrinkCount: 0,
        statistics: data.statistics
      )
      return ExecutionFailure(record: record, value: drawnValue)
    }
  }
```

Keep the old single-argument helper as a wrapper:

```swift
  func executeSingle(
    provider: some PrimitiveProvider,
    property: @Sendable (Value) throws -> Void
  ) -> ExecutionFailure<Value>? {
    executeSingle(provider: provider) { value, _ in
      try property(value)
    }
  }
```

- [ ] **Step 8: Run phase/report tests**

Run:

```bash
swift test --filter PhaseAndReportTests
```

Expected: PASS.

- [ ] **Step 9: Run strict build**

Run:

```bash
swift build --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
```

Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add Sources/PremiseCore/PropertyPhase.swift Sources/PremiseCore/RunReport.swift Sources/PremiseCore/PropertyConfig.swift Sources/PremiseCore/RunStatistics.swift Sources/PremiseCore/PremiseCore.swift Sources/PremiseCore/Runner.swift Tests/PremiseCoreTests/PhaseAndReportTests.swift
git commit -m "feat(core): add phases examples and run reports"
```

## Task 2: Surface Statistics and Health Warnings in swift-testing

**Files:**
- Modify: `Sources/PremiseTesting/FailureFormatter.swift`
- Modify: `Sources/PremiseTesting/ForAll.swift`
- Test: `Tests/PremiseTestingIntegrationTests/DataAwareForAllTests.swift`
- Test: `Tests/PremiseAdapterContractTests/DiagnosticsFormatTests.swift`

- [ ] **Step 1: Write failing adapter tests**

Create `Tests/PremiseTestingIntegrationTests/DataAwareForAllTests.swift`:

```swift
import Testing

@testable import PremiseCore
@testable import PremiseTesting

private enum DataAwareError: Error, CustomStringConvertible {
  case failed
  var description: String { "data-aware failure" }
}

@Test("Data-aware forAll allows imperative draws")
func dataAwareForAllAllowsImperativeDraws() async throws {
  try await forAll(.integers(in: 0...3), config: PropertyConfig(maxRuns: 5, seed: 1)) { value, data in
    let extra = try data.draw(.integers(in: 0...3))
    data.event(extra.isMultiple(of: 2) ? "extra-even" : "extra-odd")
    #expect((0...3).contains(value))
    #expect((0...3).contains(extra))
  }
}

@Test("Failure formatter includes statistics")
func formatterIncludesStatistics() {
  let propertyID = PropertyIdentity(
    fileID: "StatsTests",
    line: 7,
    strategyLabel: "integers"
  )
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
      HealthWarning(check: .excessiveFiltering, message: "More than half of generated examples were rejected.")
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter DataAwareForAllTests
```

Expected: FAIL because `FailureFormatter.format(... report:)` does not exist and data-aware adapter still bypasses replay-first execution.

- [ ] **Step 3: Extend FailureFormatter**

Modify `Sources/PremiseTesting/FailureFormatter.swift`.

Change the signature to include a defaulted report:

```swift
  static func format<Value>(
    value: Value,
    record: FailureRecord,
    propertyID: PropertyIdentity,
    report: RunReport? = nil
  ) -> String {
```

Insert this block after the trace-entry line:

```swift
    let statistics = report.map {
      RunStatistics(
        notes: $0.notes,
        events: $0.events.flatMap { key, count in Array(repeating: key, count: count) },
        targetScore: $0.maxTargetScore
      )
    } ?? record.statistics

    if !statistics.events.isEmpty {
      let counts = Dictionary(grouping: statistics.events, by: { $0 })
        .mapValues(\.count)
        .sorted { $0.key < $1.key }
        .map { "\($0.key)=\($0.value)" }
        .joined(separator: ", ")
      lines.append("Events: \(counts)")
    }

    if !statistics.notes.isEmpty {
      let notes = statistics.notes.map { "\($0.label)=\($0.value)" }
        .joined(separator: ", ")
      lines.append("Notes: \(notes)")
    }

    if let targetScore = statistics.targetScore {
      lines.append("Target score: \(targetScore)")
    }

    if let report, !report.healthWarnings.isEmpty {
      let warnings = report.healthWarnings.map(\.check.rawValue).joined(separator: ", ")
      lines.append("Health warnings: \(warnings)")
      for warning in report.healthWarnings {
        lines.append("- \(warning.message)")
      }
    }
```

The `RunStatistics(notes:events:targetScore:)` initializer already exists from
Task 1.

- [ ] **Step 4: Route ForAll through detailed execution**

Modify `Sources/PremiseTesting/ForAll.swift`.

In `_runForAll`, replace:

```swift
  let result = try await executor.execute(property)
```

with:

```swift
  let result = try await executor.executeDetailed(property)
```

Then pass the report to the formatter:

```swift
  if case .failure(let record, value: let value, report: let report) = result {
    let message = FailureFormatter.format(
      value: value,
      record: record,
      propertyID: propertyID,
      report: report
    )
```

Add `executeDetailed` to `Sources/PremiseDatabase/ReplayFirstExecutor.swift`:

```swift
  public func executeDetailed(
    _ property: @escaping @Sendable (Value) throws -> Void
  ) async throws -> DetailedRunResult<Value> {
    let traces = try await database.loadTraces(for: runner.propertyID)
    let result = await runner.runDetailed(property, replayTraces: traces)

    if case .failure(let record, value: _, report: _) = result {
      try await database.save(record)
      try exportTraceIfNeeded(record: record, value: result.compact.failureValue)
    }

    return result
  }
```

Keep `execute` as:

```swift
  public func execute(
    _ property: @escaping @Sendable (Value) throws -> Void
  ) async throws -> RunResult<Value> {
    try await executeDetailed(property).compact
  }
```

- [ ] **Step 5: Replace manual data-aware forAll loop**

In `Sources/PremiseTesting/ForAll.swift`, replace the data-aware `forAll` body with:

```swift
  let propertyID = PropertyIdentity(
    fileID: fileID,
    line: UInt(line),
    strategyLabel: strategy.label,
    functionName: function
  )

  let runner = Runner(
    strategy: strategy,
    config: config,
    propertyID: propertyID
  )
  let database = makeDatabase(config: config)
  let executor = ReplayFirstExecutor(runner: runner, database: database)
  let result = try await executor.executeDetailed(property)

  if case .failure(let record, value: let value, report: let report) = result {
    let message = FailureFormatter.format(
      value: value,
      record: record,
      propertyID: propertyID,
      report: report
    )
    let sourceLocation = SourceLocation(
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
    Issue.record(
      Comment(rawValue: message),
      sourceLocation: sourceLocation
    )
  }
```

- [ ] **Step 6: Run adapter tests**

Run:

```bash
swift test --filter DataAwareForAllTests
swift test --filter DiagnosticsFormatTests
```

Expected: PASS.

- [ ] **Step 7: Run strict build**

Run:

```bash
swift build --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/PremiseCore/RunStatistics.swift Sources/PremiseTesting/FailureFormatter.swift Sources/PremiseTesting/ForAll.swift Sources/PremiseDatabase/ReplayFirstExecutor.swift Tests/PremiseTestingIntegrationTests/DataAwareForAllTests.swift Tests/PremiseAdapterContractTests/DiagnosticsFormatTests.swift
git commit -m "feat(testing): surface statistics and data-aware execution"
```

## Task 3: Add Scoped Type-Driven Strategy Derivation

**Files:**
- Create: `Sources/PremiseStrategies/StrategyDerivation.swift`
- Test: `Tests/PremiseStrategiesTests/StrategyDerivationTests.swift`
- Modify: `README.md`

- [ ] **Step 1: Write failing derivation tests**

Create `Tests/PremiseStrategiesTests/StrategyDerivationTests.swift`:

```swift
import Testing

@testable import PremiseCore
@testable import PremiseStrategies

private struct UserID: Sendable, Equatable {
  let rawValue: Int
}

extension UserID: StrategyProviding {
  static func premiseStrategy(in registry: StrategyRegistry) -> Strategy<UserID> {
    registry.strategy(for: Int.self)
      .map(UserID.init(rawValue:))
      .shrinking { id in
        id.rawValue == 0 ? [] : [UserID(rawValue: 0)]
      }
  }
}

@Test("Registry derives built-in strategies by type")
func registryDerivesBuiltIns() throws {
  let strategy = StrategyRegistry.standard.strategy(for: Int.self)
  var data = PremiseData(provider: PseudoRandomProvider(seed: 1, maxDraws: 100))
  let value = try strategy.draw(&data)
  #expect((-100...100).contains(value))
}

@Test("Registry derives custom StrategyProviding types")
func registryDerivesCustomTypes() throws {
  let strategy = StrategyRegistry.standard.strategy(for: UserID.self)
  var data = PremiseData(provider: PseudoRandomProvider(seed: 1, maxDraws: 100))
  let value = try strategy.draw(&data)
  #expect((-100...100).contains(value.rawValue))
}

@Test("Registry can be overridden without global mutable state")
func registryCanBeOverridden() throws {
  let registry = StrategyRegistry.standard.register(Int.self, strategy: .just(42))
  let strategy = registry.strategy(for: Int.self)
  var data = PremiseData(provider: PseudoRandomProvider(seed: 1, maxDraws: 100))
  let value = try strategy.draw(&data)
  #expect(value == 42)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter StrategyDerivationTests
```

Expected: FAIL because `StrategyRegistry` and `StrategyProviding` do not exist.

- [ ] **Step 3: Add scoped registry**

Create `Sources/PremiseStrategies/StrategyDerivation.swift`:

```swift
import PremiseCore
import Foundation

/// A value-scoped lookup table for deriving strategies by Swift type.
///
/// The registry is immutable. Registering a strategy returns a new registry,
/// so parallel tests do not fight over global mutable state.
public struct StrategyRegistry: Sendable {
  private let entries: [ObjectIdentifier: @Sendable (StrategyRegistry) -> Any]

  public init(entries: [ObjectIdentifier: @Sendable (StrategyRegistry) -> Any] = [:]) {
    self.entries = entries
  }

  public static let standard = StrategyRegistry()
    .register(Int.self, strategy: .integers(in: -100...100))
    .register(Bool.self, strategy: .booleans)
    .register(String.self, strategy: .ascii(length: 0...32))
    .register(Double.self, strategy: .edgeCaseFloats(in: -1_000...1_000))
    .register(UUID.self, strategy: Strategy<UUID>.any)

  public func register<T: Sendable>(
    _ type: T.Type,
    strategy: Strategy<T>
  ) -> StrategyRegistry {
    register(type) { _ in strategy }
  }

  public func register<T: Sendable>(
    _ type: T.Type,
    strategy build: @escaping @Sendable (StrategyRegistry) -> Strategy<T>
  ) -> StrategyRegistry {
    var copy = entries
    copy[ObjectIdentifier(type)] = { registry in build(registry) }
    return StrategyRegistry(entries: copy)
  }

  public func strategy<T: StrategyProviding>(for type: T.Type) -> Strategy<T> {
    if let erased = entries[ObjectIdentifier(type)]?(self) as? Strategy<T> {
      return erased
    }
    return T.premiseStrategy(in: self)
  }

  public func strategy<T: Sendable>(for type: T.Type) -> Strategy<T> {
    guard let strategy = entries[ObjectIdentifier(type)]?(self) as? Strategy<T> else {
      preconditionFailure("No Premise strategy registered for \(type)")
    }
    return strategy
  }
}

/// Types that can derive a Premise strategy from a scoped registry.
public protocol StrategyProviding: Sendable {
  static func premiseStrategy(in registry: StrategyRegistry) -> Strategy<Self>
}
```

- [ ] **Step 4: Run derivation tests**

Run:

```bash
swift test --filter StrategyDerivationTests
```

Expected: PASS.

- [ ] **Step 5: Update README derivation docs**

Add this section after `Custom Strategies` in `README.md`:

```markdown
### Type-Driven Derivation

Use `StrategyRegistry` when a test helper needs a strategy by type rather than
by explicit parameter. The registry is immutable, so overrides are scoped to the
test that creates them:

```swift
let registry = StrategyRegistry.standard
    .register(UserID.self, strategy: .integers(in: 0...999).map(UserID.init))

let ids = registry.strategy(for: UserID.self)
```

Custom domain types can conform to `StrategyProviding` to derive themselves
from the registry without global mutable state.
```
```

- [ ] **Step 6: Run strict build**

Run:

```bash
swift build --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/PremiseStrategies/StrategyDerivation.swift Tests/PremiseStrategiesTests/StrategyDerivationTests.swift README.md
git commit -m "feat(strategies): add scoped type derivation"
```

## Task 4: Add Rule-Based Stateful Testing DSL

**Files:**
- Create: `Sources/PremiseTesting/RuleBasedStateMachine.swift`
- Test: `Tests/PremiseTestingIntegrationTests/RuleBasedStateMachineTests.swift`
- Modify: `README.md`

- [ ] **Step 1: Write failing state-machine tests**

Create `Tests/PremiseTestingIntegrationTests/RuleBasedStateMachineTests.swift`:

```swift
import Testing

@testable import PremiseTesting
@testable import PremiseStrategies

private struct CounterMachine: Sendable {
  var model = 0
  var system = 0
  var saved: [Int] = []
}

@Test("Rule machine executes generated operations and invariants")
func ruleMachineExecutesRulesAndInvariants() async throws {
  var machine = RuleBasedStateMachine(initialState: CounterMachine())

  machine.rule("increment", argument: Strategy<Int>.integers(in: 1...3)) { state, amount in
    state.model += amount
    state.system += amount
  }

  machine.rule(
    "decrement",
    argument: Strategy<Int>.integers(in: 1...3),
    precondition: { $0.system > 0 }
  ) { state, amount in
    state.model -= min(amount, state.model)
    state.system -= min(amount, state.system)
  }

  machine.invariant("model matches system") { state in
    #expect(state.model == state.system)
  }

  try await checkRuleBasedStateMachine(
    machine,
    config: StateMachineConfig(maxExamples: 5, maxSteps: 10, seed: 1)
  )
}

@Test("Bundles pass values between rules")
func bundlesPassValuesBetweenRules() async throws {
  var ids = StateMachineBundle<Int>("ids")
  var machine = RuleBasedStateMachine(initialState: CounterMachine())

  machine.rule("create id", argument: Strategy<Int>.integers(in: 1...5), target: ids) { state, id in
    state.saved.append(id)
    return id
  }

  machine.rule("consume id", argument: ids.strategy()) { state, id in
    #expect(state.saved.contains(id))
  }

  machine.invariant("saved ids are positive") { state in
    #expect(state.saved.allSatisfy { $0 > 0 })
  }

  try await checkRuleBasedStateMachine(
    machine,
    config: StateMachineConfig(maxExamples: 5, maxSteps: 10, seed: 1)
  )
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter RuleBasedStateMachineTests
```

Expected: FAIL because `RuleBasedStateMachine`, `StateMachineBundle`, `StateMachineConfig`, and `checkRuleBasedStateMachine` do not exist.

- [ ] **Step 3: Add state-machine implementation**

Create `Sources/PremiseTesting/RuleBasedStateMachine.swift`:

```swift
import PremiseCore
import PremiseStrategies

public struct StateMachineConfig: Sendable {
  public var maxExamples: Int
  public var maxSteps: Int
  public var seed: UInt64?

  public init(maxExamples: Int = 100, maxSteps: Int = 50, seed: UInt64? = nil) {
    self.maxExamples = maxExamples
    self.maxSteps = maxSteps
    self.seed = seed
  }
}

private final class StateMachineBundleStorage<Element: Sendable>: @unchecked Sendable {
  var values: [Element] = []
}

public struct StateMachineBundle<Element: Sendable>: Sendable {
  public let name: String
  private let storage: StateMachineBundleStorage<Element>

  public init(_ name: String) {
    self.name = name
    self.storage = StateMachineBundleStorage()
  }

  public func append(_ value: Element) {
    storage.values.append(value)
  }

  public func strategy() -> Strategy<Element> {
    Strategy<Element>(
      label: "bundle(\(name))",
      draw: { _ in
        guard let value = storage.values.first else {
          throw StrategyError.filterExhausted(label: "bundle(\(name))", maxAttempts: 1)
        }
        return value
      },
      shrink: { _ in [] }
    )
  }
}

public struct RuleBasedStateMachine<State: Sendable>: Sendable {
  public typealias Invariant = @Sendable (State) async throws -> Void

  private struct AnyRule: Sendable {
    let name: String
    let isEnabled: @Sendable (State) -> Bool
    let run: @Sendable (inout State, inout PremiseData) async throws -> Void
  }

  private let initialState: State
  private var rules: [AnyRule]
  private var invariants: [(String, Invariant)]

  public init(initialState: State) {
    self.initialState = initialState
    self.rules = []
    self.invariants = []
  }

  public mutating func rule<Argument: Sendable>(
    _ name: String,
    argument: Strategy<Argument>,
    precondition: @escaping @Sendable (State) -> Bool = { _ in true },
    body: @escaping @Sendable (inout State, Argument) async throws -> Void
  ) {
    rules.append(
      AnyRule(
        name: name,
        isEnabled: precondition,
        run: { state, data in
          let value = try data.draw(argument)
          try await body(&state, value)
        }
      )
    )
  }

  public mutating func rule<Argument: Sendable, Produced: Sendable>(
    _ name: String,
    argument: Strategy<Argument>,
    target: StateMachineBundle<Produced>,
    precondition: @escaping @Sendable (State) -> Bool = { _ in true },
    body: @escaping @Sendable (inout State, Argument) async throws -> Produced
  ) {
    rules.append(
      AnyRule(
        name: name,
        isEnabled: precondition,
        run: { state, data in
          let value = try data.draw(argument)
          let produced = try await body(&state, value)
          target.append(produced)
        }
      )
    )
  }

  public mutating func invariant(
    _ name: String,
    _ body: @escaping Invariant
  ) {
    invariants.append((name, body))
  }

  fileprivate func runOnce(seed: UInt64, maxSteps: Int) async throws {
    var state = initialState
    var data = PremiseData(provider: PseudoRandomProvider(seed: seed, maxDraws: 10_000))

    for (_, invariant) in invariants {
      try await invariant(state)
    }

    for _ in 0..<maxSteps {
      let enabled = rules.filter { $0.isEnabled(state) }
      guard !enabled.isEmpty else { return }
      let index = data.drawInteger(in: 0...(enabled.count - 1))
      let rule = enabled[index]
      data.event("rule:\(rule.name)")
      try await rule.run(&state, &data)
      for (_, invariant) in invariants {
        try await invariant(state)
      }
    }
  }
}

public func checkRuleBasedStateMachine<State: Sendable>(
  _ machine: RuleBasedStateMachine<State>,
  config: StateMachineConfig = StateMachineConfig()
) async throws {
  let baseSeed = config.seed ?? UInt64.random(in: .min ... .max)
  for index in 0..<config.maxExamples {
    try await machine.runOnce(
      seed: baseSeed &+ UInt64(index),
      maxSteps: config.maxSteps
    )
  }
}
```

- [ ] **Step 4: Run state-machine tests**

Run:

```bash
swift test --filter RuleBasedStateMachineTests
```

Expected: PASS.

- [ ] **Step 5: Add state-machine README section**

Add this to `README.md` after the existing `Stateful Testing` section:

```markdown
For workflows where the engine should choose which operation comes next,
use the rule-based DSL:

```swift
var machine = RuleBasedStateMachine(initialState: ModelAndDatabase())

machine.rule("insert", argument: Strategy<Int>.integers(in: 0...100)) { state, value in
    try await state.database.insert(value)
    state.model.insert(value)
}

machine.invariant("model matches database") { state in
    #expect(try await state.database.values() == state.model.values)
}

try await checkRuleBasedStateMachine(machine)
```
```

- [ ] **Step 6: Run strict build**

Run:

```bash
swift build --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/PremiseTesting/RuleBasedStateMachine.swift Tests/PremiseTestingIntegrationTests/RuleBasedStateMachineTests.swift README.md
git commit -m "feat(testing): add rule-based state machines"
```

## Task 5: Document the Foundation and Remaining Separate Plans

**Files:**
- Create: `Sources/PremiseCore/Documentation.docc/Articles/StatefulRuleMachines.md`
- Modify: `Sources/PremiseCore/Documentation.docc/Articles/StrategyCatalog.md`
- Modify: `README.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add stateful DocC article**

Create `Sources/PremiseCore/Documentation.docc/Articles/StatefulRuleMachines.md`:

```markdown
# Stateful Rule Machines

Use rule-based state machines when the order of operations is part of the input
space. A machine starts from an initial state, Premise chooses enabled rules,
and invariants run after every step.

```swift
var machine = RuleBasedStateMachine(initialState: IndexHarness())

machine.rule("insert", argument: Strategy<Int>.integers(in: 0...100)) { harness, value in
  harness.model.insert(value)
  try await harness.index.insert(value)
}

machine.rule("delete", argument: Strategy<Int>.integers(in: 0...100)) { harness, value in
  harness.model.remove(value)
  try await harness.index.delete(value)
}

machine.invariant("model matches index") { harness in
  #expect(try await harness.index.values() == harness.model.sorted())
}

try await checkRuleBasedStateMachine(machine)
```

Prefer a rule machine over a hand-written operation array when later operations
depend on values produced by earlier operations. Prefer `checkOperationSequence`
when you already have a concrete operation enum and only need generated lists.
```

- [ ] **Step 2: Update StrategyCatalog derivation section**

Append to `Sources/PremiseCore/Documentation.docc/Articles/StrategyCatalog.md`:

```markdown
## Type-Driven Derivation

`StrategyRegistry` derives strategies from Swift types without global mutable
state. Start with `StrategyRegistry.standard`, then register test-local
overrides:

```swift
let registry = StrategyRegistry.standard
  .register(UserID.self, strategy: .integers(in: 0...999).map(UserID.init))

let userIDs = registry.strategy(for: UserID.self)
```

Conform a domain type to `StrategyProviding` when it knows how to build itself
from the registry.
```

- [ ] **Step 3: Update changelog**

Add bullets under `CHANGELOG.md` `Added`:

```markdown
- Added explicit examples and phase selection for property runs.
- Added run reports with events, notes, target scores, and health warnings.
- Added scoped type-driven strategy derivation through `StrategyRegistry`.
- Added rule-based stateful testing with rules, preconditions, invariants, and bundles.
```

- [ ] **Step 4: Add separate-plan notes to README**

Add to `README.md` after the package structure table:

```markdown
## Still Separate From The Core

The Hypothesis-inspired ghostwriter CLI, external fuzzer bridge, and expanded
network/regex/timezone strategy catalog are intentionally separate extension
areas. They do not need to affect the macro-free `PremiseCore` path.
```

- [ ] **Step 5: Run docs scan**

Run:

```bash
rg -n "RuleBasedStateMachine|StrategyRegistry|PropertyPhase|HealthWarning" README.md CHANGELOG.md Sources/PremiseCore/Documentation.docc
```

Expected: output includes the new README, changelog, and DocC references.

- [ ] **Step 6: Run validation**

Run:

```bash
bash scripts/validate-boundaries.sh
swift package dump-package > /tmp/premise-dump-hypothesis-parity.json
swift build --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
```

Expected: all commands exit 0.

- [ ] **Step 7: Commit**

```bash
git add README.md CHANGELOG.md Sources/PremiseCore/Documentation.docc/Articles/StatefulRuleMachines.md Sources/PremiseCore/Documentation.docc/Articles/StrategyCatalog.md
git commit -m "docs: document hypothesis parity foundation"
```

## Task 6: Final Verification

**Files:**
- No edits.

- [ ] **Step 1: Run format**

Run:

```bash
/Library/Developer/CommandLineTools/usr/bin/swift-format format --in-place Package.swift Sources Tests
```

Expected: command exits 0.

- [ ] **Step 2: Run boundary validation**

Run:

```bash
bash scripts/validate-boundaries.sh
```

Expected: `boundary validation passed`.

- [ ] **Step 3: Run manifest checks**

Run:

```bash
swift package dump-package > /tmp/premise-dump-default.json
PREMISE_MACRO_SOURCE=1 swift package dump-package > /tmp/premise-dump-source-macro.json
PREMISE_MACRO_BINARY=1 PREMISE_MACRO_BINARY_CHECKSUM=1111111111111111111111111111111111111111111111111111111111111111 swift package dump-package > /tmp/premise-dump-binary-macro.json
```

Expected: all commands exit 0.

- [ ] **Step 4: Run strict builds**

Run:

```bash
swift build --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
PREMISE_MACRO_SOURCE=1 swift build -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
```

Expected: both commands exit 0.

- [ ] **Step 5: Run focused tests**

Run:

```bash
swift test --filter PhaseAndReportTests
swift test --filter DataAwareForAllTests
swift test --filter StrategyDerivationTests
swift test --filter RuleBasedStateMachineTests
```

Expected: all focused tests pass in a toolchain that provides `Testing` and `XCTest`.

- [ ] **Step 6: Run full tests**

Run:

```bash
swift test --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
```

Expected: PASS in CI or a local toolchain with `Testing` and `XCTest` available. If this local CLT environment still cannot import `Testing` or `XCTest`, record the exact module-import failure in the final handoff.

- [ ] **Step 7: Commit any formatter-only changes**

If `git status --short` shows Swift formatting edits, commit them:

```bash
git add Package.swift Sources Tests
git commit -m "style: format hypothesis parity foundation"
```

Expected: commit is created only if formatting changed files.

## Self-Review

- Spec coverage: The plan covers explicit examples, phase control, statistics/events/targets, health warnings, imperative draws, scoped strategy derivation, and rule-based state machines. It intentionally excludes ghostwriter CLI, external fuzzer bridge, and large strategy catalog extras because those are independent sub-projects.
- Placeholder scan: The plan contains no banned placeholder patterns from the skill instructions. Out-of-scope items are named as separate future plans, not hidden tasks.
- Type consistency: `PropertyPhase`, `HealthCheck`, `HealthWarning`, `RunReport`, `DetailedRunResult`, `StrategyRegistry`, `StrategyProviding`, `StateMachineConfig`, `StateMachineBundle`, `RuleBasedStateMachine`, and `checkRuleBasedStateMachine` are introduced before later tasks reference them.
