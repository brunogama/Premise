# Scripts

## Overview

Repository maintenance and release-artifact scripts.

---

## Interface

- `bash scripts/validate-boundaries.sh` checks selected package declarations, dependency edges, and prohibited test-framework imports.
- `sh scripts/format_staged_files.sh <files...>` formats staged Swift content with the root `.swift-format` while preserving unstaged edits.
- `sh scripts/test-format-staged-files.sh` verifies the formatter policy and unstaged-edit preservation in a disposable Git repository.
- `sh scripts/lint_staged_swift.sh <files...>` lints staged Swift content with staged ancestor configurations; unsupported or invalid configuration inheritance fails closed.
- `sh scripts/test-lint-staged-swift.sh` checks staged configuration inheritance and failure cases in a disposable Git repository.
- `sh scripts/run_swiftlint_analyze.sh` builds and analyzes compiled production sources. It requires SwiftLint, `pkg-config`, and Z3 development headers; retained macro sources excluded from the default package are not analyzed.
- `sh scripts/test-swiftlint-analyze.sh` checks compile-database paths, Z3 flags, and fail-closed analyzer prerequisites.
- `bash scripts/build-documentation.sh` builds a combined DocC archive with warnings treated as errors. It requires macOS, Xcode's DocC tools, and Z3 discoverable by `pkg-config`.
  The default output is `.build/Premise.doccarchive`. To avoid overwriting an existing archive, pass an unused output path as the first argument.
- `bash scripts/test-macro-exclusion.sh` verifies the release manifest and artifact guard.
- `bash scripts/test-macro-regression.sh` tests retained macros in a disposable SwiftPM package. It requires a local `swift-syntax` checkout at `.build/checkouts/swift-syntax` or the path specified by `SWIFT_SYNTAX_ROOT`.
- `bash scripts/build-macro-artifact.sh` is retained for future work and exits without building in this version.

---

## Invariants

- Boundary validation exits nonzero when a required declaration or dependency is missing or a prohibited import is found.
- The macro artifact script is retained for future work and cannot build the excluded product in this version.

---

## Side Effects

- Boundary validation reads repository source and the package manifest.
- The disabled artifact script leaves existing artifacts untouched.

---

## Verification

- From the repository root, run `bash scripts/validate-boundaries.sh` and `swift test`.
