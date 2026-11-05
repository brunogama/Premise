# Ghostwriter and Fuzzer Bridge

Generate property-test skeletons and feed byte-oriented fuzzing engines through Premise strategies.

## Overview

Hypothesis users often rely on two tooling loops: ghostwriting property tests
from a small description of the API, and connecting generated inputs to
coverage-guided fuzzers. Premise keeps those loops in leaf targets:

- `PremiseGhostwriter` renders Swift Testing skeletons for common property
  shapes.
- `PremiseFuzzing` maps raw fuzzer bytes into `PremiseData` with
  `FuzzInputProvider` and `fuzzOneInput`.

`PremiseCore` remains macro-free and storage-neutral.

## Generate Test Skeletons

Use the SwiftPM command plugin to print a skeleton you can paste into a test
file:

```bash
swift package premise-ghostwriter \
  --kind roundtrip \
  --module MyApp \
  --type Payload \
  --strategy 'Strategy<Payload>.payloads()' \
  --encode 'try JSONEncoder().encode($0)' \
  --decode 'try JSONDecoder().decode(Payload.self, from: $0)'
```

Supported `--kind` values are:

- `fuzz-no-crash`
- `roundtrip`
- `equivalence`
- `idempotence`
- `binary-operation-laws`

Expressions use `$0`, `$1`, and so on as placeholders for generated values.
For example, `--operation 'combine($0, $1)'` becomes `combine(a, b)` in a
binary-operation law test.

You can also call the renderer directly:

```swift
let source = PremiseGhostwriter.roundtrip(
    moduleName: "MyApp",
    typeName: "Payload",
    strategyExpression: "Strategy<Payload>.payloads()",
    encodeExpression: "try JSONEncoder().encode($0)",
    decodeExpression: "try JSONDecoder().decode(Payload.self, from: $0)"
)
```

## Fuzz One Input

`fuzzOneInput` interprets a single byte buffer as primitive choices for a
Premise strategy, then runs the property body if the input produced a complete
value:

```swift
import Foundation
import PremiseFuzzing
import PremiseStrategies

func fuzzPayload(_ bytes: Data) async throws {
    try await fuzzOneInput(
        bytes,
        strategy: Strategy<Payload>.payloads(),
        config: FuzzConfig(
            propertyID: PropertyIdentity(
                fileID: "PayloadFuzzer.swift",
                line: 1,
                strategyLabel: "payload-fuzzer",
                functionName: "fuzzPayload"
            )
        )
    ) { payload in
        _ = try PayloadParser.parse(payload)
    }
}
```

Draw-phase strategy errors and explicit property rejections are treated as
invalid fuzz inputs. If the byte buffer is exhausted while drawing, the
property body is skipped. If the property throws, Premise saves the failing
choice trace and the original input bytes in the configured file-backed
database.

## libFuzzer and AFL Integration

For libFuzzer, expose a C-callable entry point that converts the incoming bytes
to `Data`, then runs your async fuzz body from a task or a small synchronous
adapter appropriate for your harness:

```swift
import Foundation

final class FuzzerResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var failureMessage: String?

    func record(_ error: any Error) {
        let message = String(describing: error)
        lock.lock()
        defer { lock.unlock() }
        failureMessage = message
    }

    func recordedFailureMessage() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return failureMessage
    }
}

@_cdecl("LLVMFuzzerTestOneInput")
public func LLVMFuzzerTestOneInput(_ bytes: UnsafePointer<UInt8>, _ count: Int) -> Int32 {
    let data = Data(bytes: bytes, count: count)
    let semaphore = DispatchSemaphore(value: 0)
    let result = FuzzerResultBox()

    Task {
        do {
            try await fuzzPayload(data)
        } catch {
            result.record(error)
        }
        semaphore.signal()
    }

    semaphore.wait()
    if let failureMessage = result.recordedFailureMessage() {
        fatalError(failureMessage)
    }
    return 0
}
```

AFL-style harnesses can read `stdin` and pass the bytes to the same
`fuzzPayload(_:)` function. Keep the harness thin: all strategy decoding,
rejection handling, and failure persistence should live behind
`fuzzOneInput` so corpus entries replay through normal Premise traces.
