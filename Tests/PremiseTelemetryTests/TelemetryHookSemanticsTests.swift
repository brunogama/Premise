import PremiseCore
import PremiseTelemetry
import Testing

/// A spy sink that records all events received for test assertions.
actor SpySink: TelemetrySink {
  private(set) var events: [EngineEvent] = []

  func record(_ event: EngineEvent) async {
    events.append(event)
  }
}

@Suite("Telemetry Hook Semantics Tests")
struct TelemetryHookSemanticsTests {

  @Test("Relay forwards runStarted to a registered sink")
  func relayForwardsRunStarted() async {
    let relay = TelemetryRelay()
    let spy = SpySink()
    await relay.register(spy)

    let id = PropertyIdentity(fileID: "test", line: 1, strategyLabel: "int")
    await relay.emit(.runStarted(propertyID: id, runIndex: 0))

    let events = await spy.events
    #expect(events.count == 1)
    guard case .runStarted(let pid, let idx) = events.first else {
      Issue.record("Expected runStarted event")
      return
    }
    #expect(pid == id)
    #expect(idx == 0)
  }

  @Test("Relay forwards runFinished to a registered sink")
  func relayForwardsRunFinished() async {
    let relay = TelemetryRelay()
    let spy = SpySink()
    await relay.register(spy)

    let id = PropertyIdentity(fileID: "test", line: 2, strategyLabel: "bool")
    await relay.emit(.runFinished(propertyID: id, passed: true, runCount: 42))

    let events = await spy.events
    #expect(events.count == 1)
    guard case .runFinished(let pid, let passed, let count) = events.first else {
      Issue.record("Expected runFinished event")
      return
    }
    #expect(pid == id)
    #expect(passed == true)
    #expect(count == 42)
  }

  @Test("Relay forwards shrinkStep to a registered sink")
  func relayForwardsShrinkStep() async {
    let relay = TelemetryRelay()
    let spy = SpySink()
    await relay.register(spy)

    let id = PropertyIdentity(fileID: "test", line: 3, strategyLabel: "str")
    await relay.emit(.shrinkStep(propertyID: id, iteration: 7))

    let events = await spy.events
    #expect(events.count == 1)
    guard case .shrinkStep(let pid, let iteration) = events.first else {
      Issue.record("Expected shrinkStep event")
      return
    }
    #expect(pid == id)
    #expect(iteration == 7)
  }

  @Test("Relay forwards replayAttempt to a registered sink")
  func relayForwardsReplayAttempt() async {
    let relay = TelemetryRelay()
    let spy = SpySink()
    await relay.register(spy)

    let id = PropertyIdentity(fileID: "test", line: 4, strategyLabel: "opt")
    await relay.emit(.replayAttempt(propertyID: id, traceEntryCount: 5))

    let events = await spy.events
    #expect(events.count == 1)
    guard case .replayAttempt(let pid, let count) = events.first else {
      Issue.record("Expected replayAttempt event")
      return
    }
    #expect(pid == id)
    #expect(count == 5)
  }

  @Test("Telemetry events do not alter RunResult (sidecar semantics)")
  func telemetryDoesNotAlterRunResult() async {
    let relay = TelemetryRelay()
    let spy = SpySink()
    await relay.register(spy)

    let strategy = Strategy<Int>(label: "testInt") { data in
      data.drawInteger(in: 0...100)
    }
    let runner = Runner(strategy: strategy)

    let result = await runner.run { value in
      // Property always passes
      _ = value
    }

    // Emit events alongside
    let id = PropertyIdentity(fileID: "sidecar", line: 1, strategyLabel: "int")
    await relay.emit(.runStarted(propertyID: id, runIndex: 0))
    await relay.emit(.runFinished(propertyID: id, passed: true, runCount: 1))

    // RunResult must be passed regardless of telemetry emission
    guard case .passed = result else {
      Issue.record("Expected passed result, telemetry must not affect outcome")
      return
    }

    let events = await spy.events
    #expect(events.count == 2)
  }

  @Test("Relay with no registered sinks does not crash")
  func emptyRelayDoesNotCrash() async {
    let relay = TelemetryRelay()
    let id = PropertyIdentity(fileID: "empty", line: 1, strategyLabel: "none")

    // Should complete without error
    await relay.emit(.runStarted(propertyID: id, runIndex: 0))
    await relay.emit(.runFinished(propertyID: id, passed: true, runCount: 1))
    await relay.emit(.shrinkStep(propertyID: id, iteration: 0))
    await relay.emit(.replayAttempt(propertyID: id, traceEntryCount: 0))
  }
}
