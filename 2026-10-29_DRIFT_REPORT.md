# EGM contract drift report

The contracts were compared with the current implementation, including independent
read-only reviews of their stated interfaces, invariants, and side effects. The
reviews sampled relevant implementation seams rather than every production file;
absence of detected drift is not proof that no other discrepancy exists. The root
review covers the added blueprint, not the pre-existing user documentation.

---

## README.md and Sources/README.md

No drift detected in the reviewed blueprint and source index.

---

## Plugins/README.md

No drift detected in the reviewed contract.

---

## Plugins/PremiseGhostwriterPlugin/README.md

No drift detected in the reviewed contract.

---

## Plugins/PremiseReplayPlugin/README.md

No drift detected in the reviewed contract.

---

## scripts/README.md

No drift detected in the reviewed contract.

---

## Sources/CPremiseSanitizerCoverage/README.md

No drift detected in the reviewed contract.

---

## Sources/CPremiseSanitizerCoverage/include/README.md

No drift detected in the reviewed contract.

---

## Sources/CZ3/README.md

No drift detected in the reviewed contract.

---

## Sources/PremiseCore/README.md

The original interface omitted named public boundaries including `PropertyIdentity`,
`PseudoRandomProvider`, `ReplayProvider`, `ShrinkMachine`, `AsyncShrinkMachine`,
and `ExplicitExample`. The contract now names them. No further drift was detected
in the reviewed claims.

---

## Sources/PremiseCoverageGuided/README.md

The original interface omitted public guide and sanitizer integration types. It
also did not explain that snapshots are unavailable without instrumentation and
that resetting sanitizer coverage clears process-wide hits while preserving guard
IDs. The contract now records these details. See `CoverageMap.swift` and
`SanitizerCoverage.swift` in the same directory.

---

## Sources/PremiseDatabase/README.md

The original contract did not describe replay-first ordering or trace export's
filesystem effects. It now records trace loading, failure persistence, directory
creation, and atomic JSON export. See `ReplayFirstExecutor.swift` and
`FailureTraceExporter.swift` in the same directory.

---

## Sources/PremiseFuzzing/README.md

No drift detected in the reviewed contract.

---

## Sources/PremiseGhostwriter/README.md

The original contract said missing template expressions produce `GhostwriterError`
without distinguishing the throwing `render` API from typed helpers. Some typed
helpers call it with `try!` and can trap on an empty required expression. The
contract now makes this distinction; the implementation remains unchanged. See
`Sources/PremiseGhostwriter/Ghostwriter.swift`.

Follow-up: the four affected typed helpers now throw instead of trapping; callers
must add `try`. Regression tests cover empty required expressions.

---

## Sources/PremiseGhostwriterTool/README.md

The original contract implied every missing option value is rejected. The parser
can consume the next option token as a value, so that case may go undetected. The
contract now describes this limitation; the parser remains unchanged. See
`Sources/PremiseGhostwriterTool/main.swift`.

Follow-up: the parser now rejects option tokens in value positions, and the
command-line regression check verifies the error.

---

## Sources/PremiseMacros/README.md

The original contract omitted the generated test's adapter limit: `forAll`
provides overloads for one to three strategies. The contract now explains that
larger matching argument counts do not produce a supported call. See
`Sources/PremiseMacrosPlugin/GivenMacro.swift` and
`Sources/PremiseTesting/ForAll.swift`.

Follow-up: the retained macro now combines four or more strategies with `zip`;
its generated peer type contains a discoverable Swift Testing test.

---

## Sources/PremiseMacrosPlugin/README.md

The original contract omitted that expansion permits more than three strategies
although the generated call has no corresponding `forAll` overload. The
contract now records the distinction; macro behavior remains unchanged.

Follow-up: expansion now constructs SwiftSyntax nodes directly and supports
four or more strategies through variadic `zip`.

---

## Sources/PremiseParallel/README.md

No drift detected in the reviewed contract.

---

## Sources/PremiseReplayTool/README.md

No drift detected in the reviewed contract.

---

## Sources/PremiseSMT/README.md

The original overview implied that `SMTProvider` uses Z3 for constrained draws.
`SMTProvider.swift` delegates primitive bit and byte draws to a pseudorandom
provider regardless of the SMT trait. The contract now distinguishes that
provider from the separate trait-gated Z3 context.

---

## Sources/PremiseStrategies/README.md

No drift detected in the reviewed contract.

---

## Sources/PremiseTelemetry/README.md

No drift detected in the reviewed contract.

---

## Sources/PremiseTesting/README.md

The original interface omitted public state-machine entry points and the
`expectForAll`, `expectRoundTrip`, and `expectModelAgreement` helpers. The
contract now names them. See `PropertyPatterns.swift` and the state-machine
sources in the same directory.

---

## Sources/PremiseXCTest/README.md

No drift detected in the reviewed contract.
