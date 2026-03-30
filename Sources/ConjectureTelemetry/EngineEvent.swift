import ConjectureCore

/// Observable engine lifecycle events for telemetry consumers.
///
/// These events are purely observational and do not affect
/// replay semantics or trace content. Telemetry sinks receive
/// these events through a ``TelemetryRelay`` without any
/// back-edge into the core engine.
public enum EngineEvent: Sendable {
    /// Emitted when a property run begins execution.
    case runStarted(propertyID: PropertyIdentity, runIndex: Int)

    /// Emitted when the engine attempts to replay a stored trace.
    case replayAttempt(propertyID: PropertyIdentity, traceEntryCount: Int)

    /// Emitted on each shrink iteration during failure minimization.
    case shrinkStep(propertyID: PropertyIdentity, iteration: Int)

    /// Emitted when a property run completes, with pass/fail status.
    case runFinished(propertyID: PropertyIdentity, passed: Bool, runCount: Int)
}
