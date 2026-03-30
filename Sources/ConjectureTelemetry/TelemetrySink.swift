/// Protocol for observing engine events.
///
/// Implementations must be side-effect-free with respect to engine state.
/// A sink must not mutate traces, configurations, or results. It exists
/// solely to observe and record telemetry events for external consumers
/// such as loggers, metrics collectors, or diagnostic tools.
public protocol TelemetrySink: Sendable {
    /// Records an engine event for observation.
    ///
    /// - Parameter event: The engine lifecycle event to record.
    func record(_ event: EngineEvent) async
}
