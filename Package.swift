// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "Conjecture",
  platforms: [
    .macOS(.v13),
    .iOS(.v16),
    .tvOS(.v16),
    .watchOS(.v9),
    .visionOS(.v1),
  ],
  products: [
    .library(name: "ConjectureCore", targets: ["ConjectureCore"]),
    .library(name: "ConjectureStrategies", targets: ["ConjectureStrategies"]),
    .library(name: "ConjectureDatabase", targets: ["ConjectureDatabase"]),
    .library(name: "ConjectureTesting", targets: ["ConjectureTesting"]),
    .library(name: "ConjectureXCTest", targets: ["ConjectureXCTest"]),
    .library(name: "ConjectureParallel", targets: ["ConjectureParallel"]),
    .library(name: "ConjectureTelemetry", targets: ["ConjectureTelemetry"]),
  ],
  traits: [
    .trait(name: "CoverageGuided"),
    .trait(name: "Telemetry"),
    .trait(name: "SMT"),
    .default(enabledTraits: []),
  ],
  targets: [
    // MARK: - v1 Core Targets

    .target(name: "ConjectureCore"),
    .target(
      name: "ConjectureStrategies",
      dependencies: ["ConjectureCore"]
    ),
    .target(
      name: "ConjectureDatabase",
      dependencies: ["ConjectureCore"]
    ),
    .target(
      name: "ConjectureTesting",
      dependencies: [
        "ConjectureCore",
        "ConjectureStrategies",
        "ConjectureDatabase",
      ]
    ),
    .target(
      name: "ConjectureXCTest",
      dependencies: [
        "ConjectureCore",
        "ConjectureStrategies",
        "ConjectureDatabase",
      ]
    ),

    // MARK: - v2 Extension Targets

    .target(
      name: "ConjectureParallel",
      dependencies: ["ConjectureCore", "ConjectureDatabase"]
    ),
    .target(
      name: "ConjectureTelemetry",
      dependencies: ["ConjectureCore"]
    ),
    .target(
      name: "ConjectureCoverageGuided",
      dependencies: ["ConjectureCore"],
      swiftSettings: [
        .define("CONJECTURE_COVERAGE_GUIDED", .when(traits: ["CoverageGuided"]))
      ]
    ),
    .target(
      name: "ConjectureSMT",
      dependencies: [
        "ConjectureCore",
        .target(name: "CZ3", condition: .when(traits: ["SMT"])),
      ],
      swiftSettings: [
        .define("CONJECTURE_SMT", .when(traits: ["SMT"]))
      ]
    ),
    .systemLibrary(
      name: "CZ3",
      pkgConfig: "z3",
      providers: [.brew(["z3"]), .apt(["z3"])]
    ),

    // MARK: - v1 Test Targets

    .testTarget(
      name: "ConjectureCoreTests",
      dependencies: [
        "ConjectureCore",
        "ConjectureStrategies",
      ]
    ),
    .testTarget(
      name: "ConjectureStrategiesTests",
      dependencies: ["ConjectureStrategies"]
    ),
    .testTarget(
      name: "ConjectureDatabaseTests",
      dependencies: [
        "ConjectureCore",
        "ConjectureDatabase",
      ]
    ),
    .testTarget(
      name: "ConjectureTestingIntegrationTests",
      dependencies: ["ConjectureTesting"]
    ),
    .testTarget(
      name: "ConjectureXCTestIntegrationTests",
      dependencies: ["ConjectureXCTest"]
    ),
    .testTarget(
      name: "ConjectureAdapterContractTests",
      dependencies: [
        "ConjectureCore",
        "ConjectureStrategies",
        "ConjectureDatabase",
        "ConjectureTesting",
        "ConjectureXCTest",
      ]
    ),

    // MARK: - v2 Extension Test Targets

    .testTarget(
      name: "ConjectureParallelTests",
      dependencies: [
        "ConjectureParallel",
        "ConjectureCore",
        "ConjectureStrategies",
      ]
    ),
    .testTarget(
      name: "ConjectureTelemetryTests",
      dependencies: [
        "ConjectureTelemetry",
        "ConjectureCore",
        "ConjectureStrategies",
      ]
    ),
    .testTarget(
      name: "ConjectureCoverageGuidedTests",
      dependencies: [
        "ConjectureCoverageGuided",
        "ConjectureCore",
      ]
    ),
    .testTarget(
      name: "ConjectureSMTTests",
      dependencies: [
        "ConjectureSMT",
        "ConjectureCore",
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
