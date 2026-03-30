import XCTest

import ConjectureCore
import ConjectureDatabase
import ConjectureStrategies

/// Runs a property test through the Conjecture engine inside an XCTest
/// context.
///
/// `conjecture_forAll` constructs a ``Runner`` from the given strategy and
/// configuration, wraps it in a ``ReplayFirstExecutor`` backed by a
/// ``FileBackedDatabase``, and reports any failure through `XCTFail` at the
/// caller's source location with the minimized counterexample, run/shrink
/// counts, and a replay instruction.
///
/// - Parameters:
///   - strategy: The generation strategy that produces test values.
///   - config: Per-property execution knobs (run count, shrink limit, seed,
///     draw budget, replay behavior). Defaults to ``PropertyConfig/default``.
///   - file: Captured automatically from the call site for XCTest diagnostics.
///   - line: Captured automatically from the call site for XCTest diagnostics.
///   - property: The property closure to test. Receives a generated value and
///     should throw on failure.
public func conjecture_forAll<Value: Sendable>(
    _ strategy: Strategy<Value>,
    config: PropertyConfig = .default,
    fileID: String = #fileID,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ property: @escaping @Sendable (Value) throws -> Void
) async throws {
    let propertyID = PropertyIdentity(
        fileID: fileID,
        line: line,
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
        let message = XCTestFailureFormatter.format(
            value: value,
            record: record,
            propertyID: propertyID
        )
        XCTFail(message, file: file, line: line)
    }
}
