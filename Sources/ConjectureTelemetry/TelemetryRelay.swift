/// Actor-based relay that fans out engine events to registered sinks.
///
/// The relay holds an array of ``TelemetrySink`` conformances and
/// forwards each emitted event to all registered sinks in order.
/// When no sinks are registered, ``emit(_:)`` completes without error.
///
/// ```swift
/// let relay = TelemetryRelay()
/// await relay.register(myLogger)
/// await relay.emit(.runStarted(propertyID: id, runIndex: 0))
/// ```
public actor TelemetryRelay {
    private var sinks: [any TelemetrySink] = []

    /// Creates a new relay with no registered sinks.
    public init() {}

    /// Registers a sink to receive future events.
    ///
    /// - Parameter sink: The telemetry sink to add.
    public func register(_ sink: any TelemetrySink) {
        sinks.append(sink)
    }

    /// Emits an event to all registered sinks.
    ///
    /// Each sink receives the event in registration order. When no
    /// sinks are registered, this method returns immediately.
    ///
    /// - Parameter event: The engine event to broadcast.
    public func emit(_ event: EngineEvent) async {
        for sink in sinks {
            await sink.record(event)
        }
    }
}
