// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "MyApp",
  dependencies: [
    .package(
      url: "https://github.com/brunogama/Premise.git",
      from: "1.0.0"
    )
  ],
  targets: [
    .target(name: "MyApp"),
    .testTarget(
      name: "MyAppTests",
      dependencies: [
        "MyApp",
        .product(name: "PremiseXCTest", package: "SwiftPremise"),
        .product(name: "PremiseStrategies", package: "SwiftPremise"),
      ]
    ),
  ]
)
