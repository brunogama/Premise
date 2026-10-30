// swift-tools-version: 6.2

import PackageDescription

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
let targetDocumentationExclusions = ["README.md"]

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
  ],
  traits: [
    .trait(name: "CoverageGuided"),
    .trait(name: "Telemetry"),
    .trait(name: "SMT"),
    .default(enabledTraits: []),
  ],
  dependencies: [],
  targets: [
    .target(name: "PremiseCore", exclude: targetDocumentationExclusions),
    .target(
      name: "PremiseStrategies",
      dependencies: ["PremiseCore"],
      exclude: targetDocumentationExclusions
    ),
    .target(
      name: "PremiseDatabase",
      dependencies: ["PremiseCore"],
      exclude: targetDocumentationExclusions
    ),
    .target(
      name: "PremiseFuzzing",
      dependencies: [
        "PremiseCore",
        "PremiseDatabase",
      ],
      exclude: targetDocumentationExclusions
    ),
    .target(name: "PremiseGhostwriter", exclude: targetDocumentationExclusions),
    .executableTarget(
      name: "PremiseGhostwriterTool",
      dependencies: ["PremiseGhostwriter"],
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
    .target(
      name: "PremiseTesting",
      dependencies: [
        "PremiseCore",
        "PremiseStrategies",
        "PremiseDatabase",
      ],
      exclude: targetDocumentationExclusions
    ),
    .target(
      name: "PremiseXCTest",
      dependencies: [
        "PremiseCore",
        "PremiseStrategies",
        "PremiseDatabase",
      ],
      exclude: targetDocumentationExclusions
    ),

    .target(
      name: "PremiseParallel",
      dependencies: ["PremiseCore", "PremiseDatabase"],
      exclude: targetDocumentationExclusions
    ),
    .target(
      name: "PremiseTelemetry",
      dependencies: ["PremiseCore"],
      exclude: targetDocumentationExclusions
    ),
    .executableTarget(
      name: "PremiseReplayTool",
      dependencies: [
        "PremiseCore",
        "PremiseDatabase",
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
  ],
  swiftLanguageModes: [.v6]
)
