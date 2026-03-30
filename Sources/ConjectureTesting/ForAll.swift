import Testing

import ConjectureCore
import ConjectureDatabase
import ConjectureStrategies

/// Runs a property test through the Conjecture engine inside a swift-testing
/// context.
///
/// `forAll` constructs a ``Runner`` from the given strategy and configuration,
/// wraps it in a ``ReplayFirstExecutor`` backed by a ``FileBackedDatabase``,
/// and reports any failure as a swift-testing ``Issue`` containing the
/// minimized counterexample, run/shrink counts, and a replay instruction.
///
/// - Parameters:
///   - strategy: The generation strategy that produces test values.
///   - config: Per-property execution knobs (run count, shrink limit, seed,
///     draw budget, replay behavior). Defaults to ``PropertyConfig/default``.
///   - fileID: Captured automatically from the call site for source location.
///   - filePath: Captured automatically from the call site for diagnostics.
///   - line: Captured automatically from the call site for source location.
///   - column: Captured automatically from the call site for source location.
///   - property: The property closure to test. Receives a generated value and
///     should throw on failure.
public func forAll<Value: Sendable>(
    _ strategy: Strategy<Value>,
    config: PropertyConfig = .default,
    fileID: String = #fileID,
    filePath: String = #filePath,
    line: Int = #line,
    column: Int = #column,
    _ property: @escaping @Sendable (Value) throws -> Void
) async throws {
    let propertyID = PropertyIdentity(
        fileID: fileID,
        line: UInt(line),
        strategyLabel: strategy.label
    )

    let runner = Runner(
        strategy: strategy,
        config: config,
        propertyID: propertyID
    )

    let database = FileBackedDatabase()
    let executor = ReplayFirstExecutor(runner: runner, database: database)
    let result = try await executor.execute(property)

    if case .failure(let record, value: let value) = result {
        let message = FailureFormatter.format(
            value: value,
            record: record,
            propertyID: propertyID
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
}
