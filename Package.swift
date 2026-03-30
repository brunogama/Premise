// swift-tools-version: 6.1

import PackageDescription
import Foundation

#if canImport(CompilerPluginSupport)
import CompilerPluginSupport
#endif

// MARK: - Macro Build Mode
//
// By default, PremiseMacros uses a pre-built binary plugin so users
// don't need to compile swift-syntax (~5 min). Set the environment variable
// PREMISE_MACRO_SOURCE=1 to build the macro plugin from source instead.
//
//   PREMISE_MACRO_SOURCE=1 swift build
//
let buildMacroFromSource =
  ProcessInfo.processInfo
  .environment["PREMISE_MACRO_SOURCE"] != nil

// MARK: - Macro Targets

let macroPluginTarget: Target
let macroDependencies: [Package.Dependency]

if buildMacroFromSource {
  macroPluginTarget = .macro(
    name: "PremiseMacrosPlugin",
    dependencies: [
      .product(name: "SwiftSyntax", package: "swift-syntax"),
      .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
      .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
    ]
  )
  macroDependencies = [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.1")
  ]
} else {
  macroPluginTarget = .binaryTarget(
    name: "PremiseMacrosPlugin",
    url:
      "https://github.com/brunogama/Premise/releases/latest/download/PremiseMacrosPlugin.artifactbundle.zip",
    checksum: "0000000000000000000000000000000000000000000000000000000000000000"
  )
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
    .library(name: "PremiseTesting", targets: ["PremiseTesting"]),
    .library(name: "PremiseXCTest", targets: ["PremiseXCTest"]),
    .library(name: "PremiseParallel", targets: ["PremiseParallel"]),
    .library(name: "PremiseTelemetry", targets: ["PremiseTelemetry"]),
    .library(name: "PremiseMacros", targets: ["PremiseMacros"]),
  ],
  dependencies: macroDependencies,
  traits: [
    .trait(name: "CoverageGuided"),
    .trait(name: "Telemetry"),
    .trait(name: "SMT"),
    .default(enabledTraits: []),
  ],
  targets: [
    .target(name: "PremiseCore"),
    .target(
      name: "PremiseStrategies",
      dependencies: ["PremiseCore"]
    ),
    .target(
      name: "PremiseDatabase",
      dependencies: ["PremiseCore"]
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

    // Macro plugin target — binary or source depending on env var.
    macroPluginTarget,

    .target(
      name: "PremiseMacros",
      dependencies: ["PremiseMacrosPlugin"]
    ),

    .target(
      name: "PremiseCoverageGuided",
      dependencies: ["PremiseCore"],
      swiftSettings: [
        .define("PREMISE_COVERAGE_GUIDED", .when(traits: ["CoverageGuided"]))
      ]
    ),
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
      ]
    ),
    .testTarget(
      name: "PremiseTestingIntegrationTests",
      dependencies: ["PremiseTesting"]
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
  ],
  swiftLanguageModes: [.v6]
)
