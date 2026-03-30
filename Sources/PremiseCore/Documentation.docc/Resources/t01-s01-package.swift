// swift-tools-version: 6.1
import PackageDescription

let package = Package(
  name: "MyApp",
  dependencies: [
    .package(
      url: "https://github.com/<owner>/SwiftPremiseEngine.git",
      from: "1.0.0"
    )
  ],
  targets: [
    .target(name: "MyApp"),
    .testTarget(
      name: "MyAppTests",
      dependencies: ["MyApp"]
    ),
  ]
)
