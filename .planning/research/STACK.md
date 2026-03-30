# Technology Stack

**Project:** Premise
**Researched:** 2026-03-30
**Scope:** Stack-only research for a Swift-native property-based testing framework with fixed ARD constraints

## Recommendation

Build Premise as a pure Swift Package Manager package with `// swift-tools-version: 6.1` and `swiftLanguageModes: [.v6]`. Keep `PremiseCore` and `PremiseStrategies` free of test framework and persistence-framework imports, ship thin test-only adapters for `Testing` and XCTest, use Foundation-only file persistence in v1, and add SQLite in v2 behind a dedicated storage boundary instead of letting a database abstraction leak into the engine.

Use official SwiftPM package traits for the optional coverage-guided and SMT-backed add-ons. Traits are additive by design in SwiftPM 6.1+, which matches the ARD requirement that v2 and later extensions must not remove or alter the v1 API surface.

## Recommended Stack

### Core Package and Toolchain

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Swift Package Manager | `swift-tools-version: 6.1` | Package manifest, target graph, traits, plugins, system-library targets | SwiftPM 6.1 adds package traits, which are the cleanest official mechanism for additive optional features such as coverage-guided or SMT-backed extensions. | HIGH |
| Swift language mode | `.v6` | Strict concurrency, Sendable checking, Swift 6 semantics | Matches the ARD and aligns with Apple’s current strict-concurrency migration guidance. | HIGH |
| Foundation | toolchain / SDK | File paths, JSON serialization, file I/O, data encoding | Gives v1 persistence everything it needs without third-party dependencies. `JSONEncoder` is `Sendable`, `Data.write(to:options:)` is the canonical write API, and `FileManager.url(for:in:appropriateFor:create:)` is the canonical directory locator. | HIGH |
| Package traits | SwiftPM 6.1+ | Optional `CoverageGuided` and `SMT` add-ons | Officially additive, which is exactly what the fixed ARD wants for post-v1 capabilities. | HIGH |

### Runtime Targets

| Target | Dependencies | Purpose | Why This Shape | Confidence |
|--------|--------------|---------|----------------|------------|
| `PremiseCore` | none | Engine, trace model, shrinking, replay, protocol-witness execution | Keeps the hot path isolated from persistence, test runners, and optional extensions. | HIGH |
| `PremiseStrategies` | `PremiseCore` | Built-in strategy witnesses and combinators | Lets users depend on strategies without importing test adapters or persistence backends. | HIGH |
| `PremiseDatabase` | `PremiseCore`, Foundation; v2 may add SQLite backend target | Failure storage protocols plus concrete stores | Persistence is important, but it is still infrastructure, not engine logic. Keep it on its own boundary. | HIGH |
| `PremiseTesting` | `PremiseCore`, `PremiseStrategies`, optional `PremiseDatabase` | Swift Testing adapter | SwiftPM target docs explicitly allow test libraries, but warn that `Testing`-using targets should terminate in test contexts only. | HIGH |
| `PremiseXCTest` | `PremiseCore`, `PremiseStrategies`, optional `PremiseDatabase` | XCTest adapter | Same boundary rule as `PremiseTesting`, but preserves XCTest compatibility and performance tooling. | HIGH |
| `PremiseCoverageGuided` | `PremiseCore`; optional low-level instrumentation helper target | Opt-in coverage-guided exploration | Keeps instrumentation, unsafe flags, and experimental compiler hooks out of the default build. | MEDIUM |
| `PremiseSMT` | `PremiseCore`; solver dependency only when trait-enabled | Opt-in solver-backed provider | Preserves the engine boundary and avoids forcing a solver stack on default users. | MEDIUM |

### Testing Stack

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| `Testing` module (`swift-testing`) | bundled with Swift 6 toolchains and Xcode 16 | Primary self-test framework | Official Swift Testing supports expressive `#expect`, traits, parameterized tests, and parallel execution by default. It is the current first-choice API for package tests. | HIGH |
| XCTest | current SDK / toolchain | Compatibility adapter tests, async-expectation tests, performance microbenchmarks | XCTest remains the official compatibility layer and still provides mature expectation and `measure` APIs. | HIGH |
| `swift test` | toolchain | Package test runner | Standard package-native workflow. No Xcode project should be the source of truth. | HIGH |

### Persistence Stack

| Layer | Technology | Version | Purpose | Why | Confidence |
|-------|------------|---------|---------|-----|------------|
| v1 local store | Foundation `Codable` + `JSONEncoder` / `JSONDecoder` + `Data.write` + `FileManager` | toolchain / SDK | File-backed failure persistence | Zero extra dependencies, easy versioned record formats, portable, and fully adequate for v1. | HIGH |
| v2 SQLite backend | SQLite C API behind a SwiftPM `systemLibrary` target such as `CSQLite` | recommend SQLite `3.51.3+` or a documented backport containing the 2026 WAL-reset fix | SQLite WAL failure store | Minimal dependency surface, explicit control over WAL pragmas and checkpointing, and better fit than an app-centric ORM/query DSL for a narrow framework backend. | MEDIUM |
| Alternative v2 backend if the storage layer grows | `GRDB.swift` | `7.10.0` current release in upstream README | Higher-level SQLite toolkit | Use only if `PremiseDatabase` grows into a richer query, migration, or observation layer. GRDB is mature and concurrency-aware, but it is more library than this framework likely needs. | MEDIUM |

### Docs and Build Tooling

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Swift-DocC | toolchain | API docs and tutorials | Official Swift documentation format and the right output for a SwiftPM-first library. | HIGH |
| `swift-docc-plugin` | `1.1.0` | `swift package generate-documentation` command integration | Official SwiftPM command plugin; integrates DocC cleanly into package workflows. | HIGH |
| `swift build -Xswiftc -warnings-as-errors` | toolchain | Build gate | Fits repo rules and prevents concurrency warnings from slipping into the public API. | HIGH |
| `swift package generate-documentation` | via `swift-docc-plugin` | Static docs generation for `docs/` publishing | Official command path for package documentation. | HIGH |

### Optional Extension Tooling

| Extension | Technology | Version | Purpose | Why | Confidence |
|-----------|------------|---------|---------|-----|------------|
| Coverage-guided exploration | LLVM SanitizerCoverage | current Clang / LLVM toolchain | Edge and comparison instrumentation for a future coverage-guided engine | Official LLVM docs support `trace-pc-guard`, `trace-cmp`, `inline-8bit-counters`, and `pc-table`. Keep it isolated to an add-on target because several modes are marked experimental. | MEDIUM |
| SMT-backed provider | trait-gated solver adapter target | unpinned | Constraint solving extension | No official Swift-native SMT library emerged from this research as the clear default. Keep the stack boundary ready, but defer the actual solver choice to a phase-specific comparison. | LOW |

## Preferred Official APIs

### SwiftPM and Packaging

| API / Concept | Use | Why |
|---------------|-----|-----|
| `Package(... swiftLanguageModes: [.v6])` | Declare Swift 6 semantics explicitly | Prevents silent drift in language mode and makes strict concurrency a package-level contract. |
| `Package(... traits: ...)` | Gate additive features like `CoverageGuided` and `SMT` | Traits are officially additive and map well to optional capabilities. |
| `.target(...)`, `.testTarget(...)`, `.systemLibrary(...)`, `.plugin(...)` | Model the package graph directly in SwiftPM | These are the official target-building APIs and avoid ad hoc build systems. |
| Target test-library guidance | Keep `Testing` / XCTest out of distributable runtime targets | SwiftPM docs explicitly warn that test libraries should only terminate in test contexts. |

### v1 Persistence

| API | Use | Why |
|-----|-----|-----|
| `JSONEncoder` / `JSONDecoder` | Encode and decode versioned failure records | Official top-level JSON encoding API with straightforward `Codable` integration. |
| `Data.write(to:options:)` | Persist trace or failure blobs | Canonical Foundation write API. |
| `FileManager.url(for:in:appropriateFor:create:)` | Resolve `Application Support`, caches, or replacement directories | Canonical API for standard directory lookup and creation. |

### v2 SQLite

| API | Use | Why |
|-----|-----|-----|
| `PRAGMA journal_mode=WAL;` | Enable WAL mode | Official SQLite WAL activation path. |
| `sqlite3_libversion_number()` | Runtime version gating | Needed because WAL safety depends on the actual linked SQLite build, not just your manifest. |
| `sqlite3_prepare_v2` / binds / `sqlite3_step` / `sqlite3_finalize` | Prepared statement path | Standard, explicit, and correct low-level SQLite access pattern. |
| `sqlite3_wal_checkpoint_v2()` | Manual checkpoint control when needed | Official control point for WAL maintenance once v2 grows beyond trivial writes. |

### Testing APIs

| API | Use | Why |
|-----|-----|-----|
| `@Test`, `#expect`, `#require`, traits, arguments | Primary correctness tests | First-class Swift Testing API for expressive and parameterized tests. |
| `Trait.serialized` | File-persistence and shared-state tests | Lets you opt specific tests out of the parallel-by-default execution model. |
| `XCTestCase.measure` | Microbenchmark and regression checks | Still the official performance-measurement API for XCTest-based tests. |

## Recommended Package Structure

```text
Package.swift
Sources/
  PremiseCore/
  PremiseStrategies/
  PremiseDatabase/
    FileStore/              # v1 Foundation-backed persistence
    SQLiteStore/            # v2 only, behind a dedicated storage boundary
  PremiseTesting/        # import Testing; test-only adapter
  PremiseXCTest/         # import XCTest; test-only adapter
  PremiseCoverageGuided/ # optional, trait-gated
  PremiseSMT/            # optional, trait-gated
  CSQLite/                  # system library target when SQLite lands
Tests/
  PremiseCoreTests/
  PremiseStrategiesTests/
  PremiseDatabaseTests/
  PremiseTestingIntegrationTests/
  PremiseXCTestIntegrationTests/
  PremisePerformanceTests/   # XCTest measure-based
Documentation.docc/
Plugins/                        # only if you add package-local plugins later
```

## Testing Approach

1. Use Swift Testing as the default test authoring API for package-level tests.
2. Keep XCTest for adapter compatibility tests and performance measurements.
3. Use parameterized tests heavily for generator distributions, replay cases, and shrink oracles.
4. Use serialization traits or separate test targets for anything that touches shared files or global process state.
5. Keep adapter tests above the engine boundary. `PremiseCore` must be test-framework-agnostic.

## Persistence Approach

### v1

- Use Foundation only.
- Store versioned failure records as `Codable` values.
- Resolve storage directories through `FileManager`, not hard-coded paths.
- Keep the on-disk schema explicit and versioned from day one.

### v2

- Prefer a narrow SQLite wrapper over a general-purpose ORM as the default backend.
- Turn on WAL explicitly, and own your checkpoint policy.
- Gate WAL use on the actual SQLite version in the process, because SQLite documented a WAL-reset bug fixed on 2026-03-13 in `3.51.3`, with backports to `3.50.7` and `3.44.6`.
- If the database layer starts needing migrations, query composition, observation, or richer error surface area, reevaluate GRDB as an additive dependency inside `PremiseDatabase`, not in core.

## What Not To Use

| Category | Do Not Use | Why | Use Instead |
|----------|------------|-----|-------------|
| Package source of truth | Xcode project files, CocoaPods, Carthage | The framework is package-first and must remain SwiftPM-native. Extra package managers add no value here. | SwiftPM only |
| Core target dependencies | `Testing` or XCTest in `PremiseCore` or `PremiseStrategies` | SwiftPM warns testing libraries should only terminate in test contexts, and the ARD requires core isolation. | Thin adapter targets only |
| v1 persistence | GRDB or SQLite.swift in the initial release | v1 only needs deterministic local failure storage. A database dependency is premature. | Foundation-only file store |
| Default v2 SQLite abstraction | SQLite.swift | Nice query DSL, but it does not buy much for a narrow failure store and does not offer a stronger concurrency story than a direct backend or GRDB. | Raw SQLite wrapper first; GRDB only if the storage layer grows |
| Documentation stack | Jazzy as the primary docs path | DocC is the official Swift documentation system and integrates directly with SwiftPM. | DocC + `swift-docc-plugin` |
| Coverage-guided default build | SanitizerCoverage in the default package products | Some instrumentation modes are experimental and the integration surface is compiler-flag-heavy. | Trait-gated add-on target |

## Installation

### Manifest baseline

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Premise",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "PremiseCore", targets: ["PremiseCore"]),
        .library(name: "PremiseStrategies", targets: ["PremiseStrategies"]),
        .library(name: "PremiseDatabase", targets: ["PremiseDatabase"]),
        .library(name: "PremiseTesting", targets: ["PremiseTesting"]),
        .library(name: "PremiseXCTest", targets: ["PremiseXCTest"]),
    ],
    traits: [
        .trait(name: "CoverageGuided"),
        .trait(name: "SMT"),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.1.0"),
    ],
    swiftLanguageModes: [.v6],
    targets: [
        .target(name: "PremiseCore"),
        .target(name: "PremiseStrategies", dependencies: ["PremiseCore"]),
        .target(name: "PremiseDatabase", dependencies: ["PremiseCore"]),
        .target(name: "PremiseTesting", dependencies: [
            "PremiseCore", "PremiseStrategies", "PremiseDatabase",
        ]),
        .target(name: "PremiseXCTest", dependencies: [
            "PremiseCore", "PremiseStrategies", "PremiseDatabase",
        ]),
        .testTarget(name: "PremiseCoreTests", dependencies: ["PremiseCore"]),
    ]
)
```

### Build and docs commands

```bash
swift build -Xswiftc -warnings-as-errors
swift test
swift package --allow-writing-to-directory ./docs generate-documentation \
  --target PremiseCore --output-path ./docs
```

### SQLite when v2 lands

```swift
.systemLibrary(name: "CSQLite", pkgConfig: "sqlite3")
```

If you need a higher-level SQLite layer instead of a thin wrapper, evaluate:

```swift
.package(url: "https://github.com/groue/GRDB.swift.git", from: "7.10.0")
```

## Confidence

| Area | Level | Notes |
|------|-------|-------|
| Core package/toolchain | HIGH | Backed by SwiftPM PackageDescription docs, Swift language mode docs, and Apple strict-concurrency guidance. |
| Test stack | HIGH | Backed by official Swift Testing repo docs and Apple XCTest docs. |
| Docs/build tooling | HIGH | Backed by SwiftPM docs and the official `swift-docc-plugin` project docs. |
| v1 persistence | HIGH | Backed by Foundation docs for JSON encoding, file writes, and directory resolution. |
| v2 SQLite backend choice | MEDIUM | SQLite WAL behavior is primary-source-backed, but the final choice between a raw wrapper and GRDB is an engineering recommendation based on the framework’s narrow storage scope. |
| Coverage-guided extension path | MEDIUM | LLVM instrumentation APIs are official, but Swift-target integration still needs a dedicated implementation spike. |
| SMT library selection | LOW | This research established the packaging boundary, not the solver choice. |

## Sources

### Primary (HIGH confidence)

- Swift Package Manager `Package`: https://docs.swift.org/swiftpm/documentation/packagedescription/package
- Swift Package Manager `Target`: https://docs.swift.org/swiftpm/documentation/packagedescription/target
- Swift Package Manager `SwiftLanguageMode`: https://docs.swift.org/swiftpm/documentation/packagedescription/swiftlanguagemode
- Swift Package Manager `Trait`: https://docs.swift.org/swiftpm/documentation/packagedescription/trait
- Swift Package Manager project README: https://github.com/swiftlang/swift-package-manager
- Swift Testing README: https://github.com/swiftlang/swift-testing/blob/main/README.md
- Swift Testing docs: `DefiningTests.md` and `Traits.md` in `swiftlang/swift-testing`
- Apple strict concurrency migration sample: https://developer.apple.com/documentation/swift/updating-an-app-to-use-strict-concurrency#Adopt-strict-concurrency-checking-in-Swift
- Apple `XCTestCase` docs: https://developer.apple.com/documentation/xctest/xctestcase
- Apple `JSONEncoder` docs: https://developer.apple.com/documentation/foundation/jsonencoder
- Apple `Data.write(to:options:)` docs: https://developer.apple.com/documentation/foundation/data/write(to:options:)
- Apple `FileManager.url(for:in:appropriateFor:create:)` docs: https://developer.apple.com/documentation/foundation/filemanager/url(for:in:appropriatefor:create:)
- `swift-docc-plugin` docs / README: https://github.com/swiftlang/swift-docc-plugin and https://swiftlang.github.io/swift-docc-plugin/documentation/swiftdoccplugin/
- SQLite WAL docs: https://www.sqlite.org/wal.html
- LLVM SanitizerCoverage docs: https://clang.llvm.org/docs/SanitizerCoverage.html

### Secondary (MEDIUM confidence)

- GRDB README and documentation links: https://github.com/groue/GRDB.swift/blob/main/README.md
- SQLite.swift README: https://github.com/stephencelis/SQLite.swift

### Research Notes

- `ref-cli` search returned backend 404s in this environment, and the local `exa.py` wrapper returned a paid-plan error, so discovery fell back to direct official URLs plus GitHub and documentation connectors. This does not affect the primary-source conclusions above.
