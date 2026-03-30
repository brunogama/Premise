import ConjectureCore

/// Formats a property failure into a human-readable diagnostic string
/// for XCTest output containing the counterexample, run/shrink counts,
/// and replay instructions.
enum XCTestFailureFormatter {
    /// Builds a diagnostic message from a property failure.
    ///
    /// - Parameters:
    ///   - value: The minimized counterexample that triggered the failure.
    ///   - record: The failure record containing trace, counts, and metadata.
    ///   - propertyID: The property identity for replay instructions.
    /// - Returns: A multi-line diagnostic string.
    static func format<Value>(
        value: Value,
        record: FailureRecord,
        propertyID: PropertyIdentity
    ) -> String {
        var lines: [String] = []
        lines.append("Property failed: \(propertyID.fileID)#\(propertyID.line)")
        lines.append("Counterexample: \(value)")
        lines.append("Error: \(record.errorMessage)")
        lines.append("Runs: \(record.runCount), Shrinks: \(record.shrinkCount)")
        lines.append(
            "Replay: use seed or trace from "
                + ".conjecture/examples to reproduce this failure."
        )
        return lines.joined(separator: "\n")
    }
}
