// swift-tools-version: 6.2

import PackageDescription
import Foundation

#if canImport(CompilerPluginSupport)
import CompilerPluginSupport
#endif

// MARK: - Macro Build Mode
//
// Macro sugar is optional. The default manifest keeps the core package path
// free of both swift-syntax and prebuilt binary downloads:
//
//   swift build --product PremiseTesting
//
// To work on @given locally, build the macro from source:
//
//   PREMISE_MACRO_SOURCE=1 swift build --product PremiseMacros
//
// Release automation can validate the binary-backed macro target by supplying
// both PREMISE_MACRO_BINARY=1 and PREMISE_MACRO_BINARY_CHECKSUM=<checksum>.
let environment = ProcessInfo.processInfo.environment
let buildMacroFromSource = environment["PREMISE_MACRO_SOURCE"] != nil
let buildBinaryMacro = environment["PREMISE_MACRO_BINARY"] != nil

// MARK: - Macro Targets

let macroProducts: [Product]
let macroTargets: [Target]
let macroDependencies: [Package.Dependency]

if buildMacroFromSource {
  macroProducts = [
    .library(name: "PremiseMacros", targets: ["PremiseMacros"])
  ]
  macroTargets = [
    .macro(
      name: "PremiseMacrosPlugin",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),
    .target(
      name: "PremiseMacros",
      dependencies: ["PremiseMacrosPlugin"]
    ),
    .testTarget(
      name: "PremiseMacrosTests",
      dependencies: [
        "PremiseMacrosPlugin",
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
  ]
  macroDependencies = [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0")
  ]
} else if buildBinaryMacro {
  guard let checksum = environment["PREMISE_MACRO_BINARY_CHECKSUM"],
    !checksum.isEmpty
  else {
    fatalError(
      "PREMISE_MACRO_BINARY requires PREMISE_MACRO_BINARY_CHECKSUM"
    )
  }

  macroProducts = [
    .library(name: "PremiseMacros", targets: ["PremiseMacros"])
  ]
  macroTargets = [
    .binaryTarget(
      name: "PremiseMacrosPlugin",
      url:
        "https://github.com/brunogama/Premise/releases/download/v1.0.0/PremiseMacrosPlugin.artifactbundle.zip",
      checksum: checksum
    ),
    .target(
      name: "PremiseMacros",
      dependencies: ["PremiseMacrosPlugin"]
    ),
  ]
  macroDependencies = []
} else {
  macroProducts = []
  macroTargets = []
  macroDependencies = []
}

// MARK: - Package

let package = Package(
  name: "SwiftPremise",
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
    .library(name: "PremiseFuzzing", targets: ["PremiseFuzzing"]),
    .library(name: "PremiseGhostwriter", targets: ["PremiseGhostwriter"]),
    .library(name: "PremiseTesting", targets: ["PremiseTesting"]),
    .library(name: "PremiseXCTest", targets: ["PremiseXCTest"]),
    .library(name: "PremiseParallel", targets: ["PremiseParallel"]),
    .library(name: "PremiseTelemetry", targets: ["PremiseTelemetry"]),
    .library(name: "PremiseCoverageGuided", targets: ["PremiseCoverageGuided"]),
    .executable(name: "PremiseGhostwriterTool", targets: ["PremiseGhostwriterTool"]),
    .executable(name: "PremiseReplayTool", targets: ["PremiseReplayTool"]),
  ] + macroProducts,
  traits: [
    .trait(name: "CoverageGuided"),
    .trait(name: "Telemetry"),
    .trait(name: "SMT"),
    .default(enabledTraits: []),
  ],
  dependencies: macroDependencies,
  targets: [
    .target(
      name: "PremiseCore",
      resources: [.copy("Documentation.docc")]
    ),
    .target(
      name: "PremiseStrategies",
      dependencies: ["PremiseCore"]
    ),
    .target(
      name: "PremiseDatabase",
      dependencies: ["PremiseCore", "PremiseSQLite"]
    ),
    // Re-exports Darwin's SQLite3 module or the Linux CSQLite shim so that
    // sqlite-facing files need one unconditional import.
    .target(
      name: "PremiseSQLite",
      dependencies: [
        .target(name: "CSQLite", condition: .when(platforms: [.linux]))
      ]
    ),
    // Shared stdio for the command-line tools; avoids C stdio globals that
    // Swift 6 strict concurrency rejects on Linux.
    .target(name: "PremiseToolSupport"),
    .target(
      name: "PremiseFuzzing",
      dependencies: [
        "PremiseCore",
        "PremiseDatabase",
      ]
    ),
    .target(name: "PremiseGhostwriter"),
    .executableTarget(
      name: "PremiseGhostwriterTool",
      dependencies: ["PremiseGhostwriter", "PremiseToolSupport"]
    ),
    .plugin(
      name: "PremiseGhostwriterPlugin",
      capability: .command(
        intent: .custom(
          verb: "premise-ghostwriter",
          description: "Generate Premise property-test skeletons"
        )
      ),
      dependencies: ["PremiseGhostwriterTool"]
    ),
    .target(
      name: "PremiseTesting",
      dependencies: [
        "PremiseCore",
        "PremiseStrategies",
        "PremiseDatabase",
      ]
    ),
    .target(
      name: "PremiseXCTest",
      dependencies: [
        "PremiseCore",
        "PremiseStrategies",
        "PremiseDatabase",
      ]
    ),

    .target(
      name: "PremiseParallel",
      dependencies: ["PremiseCore", "PremiseDatabase"]
    ),
    .target(
      name: "PremiseTelemetry",
      dependencies: ["PremiseCore"]
    ),
    .executableTarget(
      name: "PremiseReplayTool",
      dependencies: [
        "PremiseCore",
        "PremiseDatabase",
        "PremiseToolSupport",
      ]
    ),
    .plugin(
      name: "PremiseReplayPlugin",
      capability: .command(
        intent: .custom(
          verb: "premise-replay",
          description: "Inspect and decode Premise replay trace artifacts"
        )
      ),
      dependencies: ["PremiseReplayTool"]
    ),

    .target(
      name: "PremiseCoverageGuided",
      dependencies: [
        "PremiseCore",
        "CPremiseSanitizerCoverage",
      ],
      swiftSettings: [
        .define("PREMISE_COVERAGE_GUIDED", .when(traits: ["CoverageGuided"]))
      ]
    ),
    .target(name: "CPremiseSanitizerCoverage"),
    .target(
      name: "PremiseSMT",
      dependencies: [
        "PremiseCore",
        .target(name: "CZ3", condition: .when(traits: ["SMT"])),
      ],
      swiftSettings: [
        .define("PREMISE_SMT", .when(traits: ["SMT"]))
      ]
    ),
    .systemLibrary(
      name: "CZ3",
      pkgConfig: "z3",
      providers: [.brew(["z3"]), .apt(["z3"])]
    ),
    // Darwin ships the SQLite3 module; Linux needs the system library shim.
    .systemLibrary(
      name: "CSQLite",
      pkgConfig: "sqlite3",
      providers: [.brew(["sqlite"]), .apt(["libsqlite3-dev"])]
    ),

    // MARK: - v1 Test Targets

    .testTarget(
      name: "PremiseCoreTests",
      dependencies: [
        "PremiseCore",
        "PremiseStrategies",
      ]
    ),
    .testTarget(
      name: "PremiseStrategiesTests",
      dependencies: ["PremiseStrategies"]
    ),
    .testTarget(
      name: "PremiseDatabaseTests",
      dependencies: [
        "PremiseCore",
        "PremiseDatabase",
        "PremiseSQLite",
      ]
    ),
    .testTarget(
      name: "PremiseFuzzingTests",
      dependencies: [
        "PremiseCore",
        "PremiseDatabase",
        "PremiseFuzzing",
        "PremiseStrategies",
      ]
    ),
    .testTarget(
      name: "PremiseGhostwriterTests",
      dependencies: ["PremiseGhostwriter"]
    ),
    .testTarget(
      name: "PremiseTestingIntegrationTests",
      dependencies: ["PremiseTesting", "PremiseDatabase"]
    ),
    .testTarget(
      name: "PremiseXCTestIntegrationTests",
      dependencies: ["PremiseXCTest"]
    ),
    .testTarget(
      name: "PremiseAdapterContractTests",
      dependencies: [
        "PremiseCore",
        "PremiseStrategies",
        "PremiseDatabase",
        "PremiseTesting",
        "PremiseXCTest",
      ]
    ),

    // MARK: - v2 Extension Test Targets

    .testTarget(
      name: "PremiseParallelTests",
      dependencies: [
        "PremiseParallel",
        "PremiseCore",
        "PremiseStrategies",
      ]
    ),
    .testTarget(
      name: "PremiseTelemetryTests",
      dependencies: [
        "PremiseTelemetry",
        "PremiseCore",
        "PremiseStrategies",
      ]
    ),
    .testTarget(
      name: "PremiseCoverageGuidedTests",
      dependencies: [
        "PremiseCoverageGuided",
        "PremiseCore",
      ]
    ),
    .testTarget(
      name: "PremiseSMTTests",
      dependencies: [
        "PremiseSMT",
        "PremiseCore",
      ]
    ),
  ] + macroTargets,
  swiftLanguageModes: [.v6]
)
