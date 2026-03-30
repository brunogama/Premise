# Telemetry and Observability

Observe the engine's lifecycle events without affecting test results.

## Overview

`PremiseTelemetry` provides a lightweight, actor-based observability layer for the Premise engine. It lets you log run progress, collect metrics, drive dashboards, or feed data into your CI observability pipeline — all without modifying the engine's core behaviour.

The design principle is strict: telemetry observers can only *read* events. They cannot modify traces, values, or results. The engine remains deterministic regardless of what telemetry sinks are attached.

## The Three Types

### EngineEvent

``EngineEvent`` is a `Sendable` enum describing the observable moments in an engine lifecycle:

```swift
public enum EngineEvent: Sendable {
    case runStarted(propertyID: PropertyIdentity, runIndex: Int)
    case replayAttempt(propertyID: PropertyIdentity, traceEntryCount: Int)
    case shrinkStep(propertyID: PropertyIdentity, iteration: Int)
    case runFinished(propertyID: PropertyIdentity, passed: Bool, runCount: Int)
}
```

### TelemetrySink

``TelemetrySink`` is the observer protocol:

```swift
public protocol TelemetrySink: Sendable {
    func record(_ event: EngineEvent) async
}
```

Implement this to receive events. The `async` signature gives your implementation freedom to forward events to an actor, write to a file, post to a metrics endpoint, or anything else — without blocking the engine.

### TelemetryRelay

``TelemetryRelay`` is an actor that fans out events to all registered sinks:

```swift
public actor TelemetryRelay {
    public func register(_ sink: any TelemetrySink)
    public func emit(_ event: EngineEvent) async
}
```

Create one relay, register your sinks, and pass it to the engine. Events are delivered in sink registration order.

## Writing a Sink

### Console logger

```swift
public struct ConsoleSink: TelemetrySink {
    public init() {}
    public func record(_ event: EngineEvent) async {
        switch event {
        case .runStarted(let id, let index):
            print("[\(id.strategyLabel)] run \(index) started")
        case .replayAttempt(let id, let count):
            print("[\(id.strategyLabel)] replaying trace with \(count) entries")
        case .shrinkStep(let id, let iteration):
            print("[\(id.strategyLabel)] shrink step \(iteration)")
        case .runFinished(let id, let passed, let count):
            let status = passed ? "PASS" : "FAIL"
            print("[\(id.strategyLabel)] \(status) after \(count) runs")
        }
    }
}
```

### Metrics counter

```swift
public actor MetricsSink: TelemetrySink {
    public private(set) var totalRuns = 0
    public private(set) var totalFailures = 0
    public private(set) var totalShrinkSteps = 0

    public func record(_ event: EngineEvent) async {
        switch event {
        case .runStarted:       totalRuns += 1
        case .runFinished(_, let passed, _): if !passed { totalFailures += 1 }
        case .shrinkStep:       totalShrinkSteps += 1
        case .replayAttempt:    break
        }
    }
}
```

### Structured JSON logger (for CI pipelines)

```swift
public struct JSONLinesSink: TelemetrySink {
    private let stream: AsyncStream<String>.Continuation
    public init(continuation: AsyncStream<String>.Continuation) {
        self.stream = continuation
    }

    public func record(_ event: EngineEvent) async {
        let line: [String: Any]
        switch event {
        case .runStarted(let id, let index):
            line = ["event": "runStarted", "strategy": id.strategyLabel, "index": index]
        case .runFinished(let id, let passed, let count):
            line = ["event": "runFinished", "strategy": id.strategyLabel,
                    "passed": passed, "runs": count]
        case .shrinkStep(let id, let iteration):
            line = ["event": "shrinkStep", "strategy": id.strategyLabel, "iteration": iteration]
        case .replayAttempt(let id, let count):
            line = ["event": "replayAttempt", "strategy": id.strategyLabel, "entries": count]
        }
        if let data = try? JSONSerialization.data(withJSONObject: line),
           let json = String(data: data, encoding: .utf8) {
            stream.yield(json)
        }
    }
}
```

## Using the Relay

Create a relay, register sinks, then emit events around your engine calls:

```swift
let relay = TelemetryRelay()
let metrics = MetricsSink()
await relay.register(ConsoleSink())
await relay.register(metrics)

let propertyID = PropertyIdentity(fileID: #fileID, line: #line, strategyLabel: "integers")
let runner = Runner(
    strategy: Strategy<Int>.integers(in: 0...1000),
    config: .default,
    propertyID: propertyID
)

await relay.emit(.runStarted(propertyID: propertyID, runIndex: 0))
let result = await runner.run { value in
    // ...
}
await relay.emit(.runFinished(
    propertyID: propertyID,
    passed: { if case .passed = result { return true }; return false }(),
    runCount: 100
))

let total = await metrics.totalRuns
print("Total tracked runs: \(total)")
```

## Injecting Telemetry via PropertyConfig

In V2, ``PropertyConfig`` will gain a `telemetry` field so sinks are attached directly to properties without manual relay wiring. In the current version, wire the relay around your runner calls as shown above.

## Performance Considerations

- `TelemetrySink.record` is `async`. If your sink does significant work (network I/O, disk writes), ensure it doesn't introduce latency that compounds across hundreds of runs.
- For high-run-count properties, consider batching events in your sink instead of forwarding each one immediately.
- If you don't need telemetry in production CI, don't register any sinks — the relay returns immediately when the sink list is empty.

## Next Steps

- See <doc:ParallelTesting> for parallel execution details.
- Read <doc:SwiftConcurrencySafety> for the actor and `Sendable` design behind the telemetry layer.
