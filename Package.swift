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

let targetDocumentationExclusions = ["README.md"]

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
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ],
      exclude: targetDocumentationExclusions
    ),
    .target(
      name: "PremiseMacros",
      dependencies: ["PremiseMacrosPlugin"],
      exclude: targetDocumentationExclusions
    ),
    .testTarget(
      name: "PremiseMacrosTests",
      dependencies: [
        "PremiseMacrosPlugin",
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(
          name: "SwiftSyntaxMacrosGenericTestSupport",
          package: "swift-syntax"
        ),
      ],
      resources: [.copy("Fixtures")]
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
        "https://github.com/brunogama/Premise/releases/download/v1.0.2/PremiseMacrosPlugin.artifactbundle.zip",
      checksum: checksum
    ),
    .target(
      name: "PremiseMacros",
      dependencies: ["PremiseMacrosPlugin"],
      exclude: targetDocumentationExclusions
    ),
  ]
  macroDependencies = []
} else {
  macroProducts = []
  macroTargets = []
  macroDependencies = []
}

// MARK: - Package

let libraryNames = [
  "PremiseCore",
  "PremiseStrategies",
  "PremiseDatabase",
  "PremiseFuzzing",
  "PremiseGhostwriter",
  "PremiseTesting",
  "PremiseXCTest",
  "PremiseParallel",
  "PremiseTelemetry",
  "PremiseCoverageGuided",
]

let testDependencies: [String: [Target.Dependency]] = [
  "PremiseCoreTests": ["PremiseCore", "PremiseStrategies"],
  "PremiseStrategiesTests": ["PremiseStrategies"],
  "PremiseDatabaseTests": ["PremiseCore", "PremiseDatabase", "PremiseSQLite"],
  "PremiseFuzzingTests": [
    "PremiseCore",
    "PremiseDatabase",
    "PremiseFuzzing",
    "PremiseStrategies",
  ],
  "PremiseGhostwriterTests": ["PremiseGhostwriter"],
  "PremiseTestingIntegrationTests": ["PremiseTesting", "PremiseDatabase"],
  "PremiseXCTestIntegrationTests": ["PremiseXCTest"],
  "PremiseAdapterContractTests": [
    "PremiseCore",
    "PremiseStrategies",
    "PremiseDatabase",
    "PremiseTesting",
    "PremiseXCTest",
  ],
  "PremiseParallelTests": [
    "PremiseParallel",
    "PremiseCore",
    "PremiseStrategies",
  ],
  "PremiseTelemetryTests": [
    "PremiseTelemetry",
    "PremiseCore",
    "PremiseStrategies",
  ],
  "PremiseCoverageGuidedTests": ["PremiseCoverageGuided", "PremiseCore"],
  "PremiseSMTTests": ["PremiseSMT", "PremiseCore"],
]

let libraryDependencies: [String: [Target.Dependency]] = [
  "PremiseCore": [],
  "PremiseStrategies": ["PremiseCore"],
  "PremiseDatabase": ["PremiseCore", "PremiseSQLite"],
  "PremiseFuzzing": ["PremiseCore", "PremiseDatabase"],
  "PremiseGhostwriter": [],
  "PremiseTesting": ["PremiseCore", "PremiseStrategies", "PremiseDatabase"],
  "PremiseXCTest": ["PremiseCore", "PremiseStrategies", "PremiseDatabase"],
  "PremiseParallel": ["PremiseCore", "PremiseDatabase"],
  "PremiseTelemetry": ["PremiseCore"],
]

let package = Package(
  name: "Premise",
  platforms: [
    .macOS(.v13),
    .iOS(.v16),
    .tvOS(.v16),
    .watchOS(.v9),
    .visionOS(.v1),
  ],
  products: libraryNames.map { .library(name: $0, targets: [$0]) } + [
    .executable(
      name: "PremiseGhostwriterTool",
      targets: ["PremiseGhostwriterTool"]
    ),
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

    .executableTarget(
      name: "PremiseGhostwriterTool",
      dependencies: ["PremiseGhostwriter", "PremiseToolSupport"],
      exclude: targetDocumentationExclusions
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

    .executableTarget(
      name: "PremiseReplayTool",
      dependencies: [
        "PremiseCore",
        "PremiseDatabase",
        "PremiseToolSupport",
      ],
      exclude: targetDocumentationExclusions
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
      exclude: targetDocumentationExclusions,
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
      exclude: targetDocumentationExclusions,
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

  ] + macroTargets
    + libraryDependencies.sorted { $0.key < $1.key }.map {
      .target(
        name: $0.key,
        dependencies: $0.value,
        exclude: targetDocumentationExclusions
      )
    }
    + testDependencies.sorted { $0.key < $1.key }.map {
      .testTarget(name: $0.key, dependencies: $0.value)
    },
  swiftLanguageModes: [.v6]
)
