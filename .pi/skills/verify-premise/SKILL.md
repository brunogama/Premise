---
name: verify-premise
description: Verify Swift Premise through a disposable SwiftPM consumer and its command plugins after library or tooling changes.
---

# Verify Swift Premise

Premise is a Swift property-testing library. Its primary user surface is a SwiftPM consumer using `PremiseCore`, `PremiseStrategies`, and `PremiseTesting`. The `premise-ghostwriter` and `premise-replay` SwiftPM plugins are secondary surfaces. Read `features/README.md` and the relevant feature file before driving. This is a focused verification recipe, not a substitute for the repository's required full gates.

---
## Launch

From the repository root, in a bash shell, create separate scratch and evidence directories. The default package has no remote dependencies; do not set `PREMISE_MACRO_SOURCE` or `PREMISE_MACRO_BINARY`. Swift 6.2+ with Swift Testing is required. Never use another run's scratch directory or shared database.

```bash
export PREMISE_ROOT="$PWD"
export SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/premise-verify.XXXXXX")"
export EVIDENCE="$(mktemp -d "${TMPDIR:-/tmp}/premise-evidence.XXXXXX")"
mkdir -p "$SCRATCH/Tests/PremiseVerificationTests"
cat > "$SCRATCH/Package.swift" <<'SWIFT'
// swift-tools-version: 6.2
import Foundation
import PackageDescription
let package = Package(
  name: "PremiseVerification",
  dependencies: [.package(path: ProcessInfo.processInfo.environment["PREMISE_ROOT"]!)],
  targets: [.testTarget(name: "PremiseVerificationTests", dependencies: [
    .product(name: "PremiseCore", package: "Premise"),
    .product(name: "PremiseTesting", package: "Premise"),
    .product(name: "PremiseStrategies", package: "Premise"),
  ])]
)
SWIFT
cat > "$SCRATCH/Tests/PremiseVerificationTests/PropertyTests.swift" <<'SWIFT'
import PremiseCore
import PremiseStrategies
import PremiseTesting
import Testing

@Test func additionIsCommutative() async throws {
  try await forAll(
    Strategy<Int>.integers(in: -1_000...1_000),
    Strategy<Int>.integers(in: -1_000...1_000)
  ) { x, y in
    #expect(x + y == y + x)
  }
}
SWIFT
printf 'root=%s\nscratch=%s\nevidence=%s\n' "$PREMISE_ROOT" "$SCRATCH" "$EVIDENCE"
```

The first drive builds the disposable consumer and is ready only when Swift Testing discovers and executes the property. For command plugins, use the current checkout; do not claim an installed release was tested.

---
## Doctor

Run `swift --version` and `test -f "$PREMISE_ROOT/Package.swift" && test -f "$SCRATCH/Package.swift"`. Confirm Swift 6.2+ and that `PREMISE_ROOT` names the intended checkout. If builds fail, preserve the full log and stop; do not download dependencies or reuse another run's state without authorization. Optional macro and solver configurations are outside this default setup.

---
## Drive

Use the feature map. Start with the real public consumer path:

```bash
(
  cd "$SCRATCH" || exit 1
  printf '%s\n' 'Action: swift test --disable-xctest --disable-automatic-resolution'
  swift --version
  swift test --disable-xctest --disable-automatic-resolution
  rc=$?
  printf 'exit_code=%s\n' "$rc"
  exit "$rc"
) > "$EVIDENCE/consumer-property.log" 2>&1
rc=$?
tail -n 20 "$EVIDENCE/consumer-property.log"
test "$rc" -eq 0
grep -E 'Test additionIsCommutative\(\) passed' "$EVIDENCE/consumer-property.log"
```

Require exit 0 and a Swift Testing result showing `additionIsCommutative` passed; zero discovered tests is not proof. This recipe uses the local checkout as a path dependency and does not verify remote installation, released artifacts, Apple device platforms, or macro mode.

---
## Evidence

Retain `$EVIDENCE` outside `$SCRATCH`. Record the checkout revision (`git -C "$PREMISE_ROOT" rev-parse HEAD`), dirty status, command, output, exit code, and feature/entry point. Preserve full logs, including failures, without credentials. Exercise public user paths, capture both action and resulting state, and check side effects separately where applicable. Do not treat mocks or a dry-run as proof of the real path without observing what they skip. Never overwrite evidence from a previous run.

---
## Cleanup

After every attempt, including failures, remove only the exact scratch directory created by this run: `rm -rf -- "$SCRATCH"`. There is no server to kill. Confirm `test ! -e "$SCRATCH" && test -s "$EVIDENCE/consumer-property.log"`; retain and report `$EVIDENCE`. If a command starts a child process, wait for or terminate only the process it started. Never remove the evidence directory as part of cleanup.

---
## Helpers

No helper scripts are required. Run the commands above and in the feature map literally, using one bash session so exported paths persist.
