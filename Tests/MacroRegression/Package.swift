// swift-tools-version: 6.2
import CompilerPluginSupport
import Foundation
import PackageDescription

let environment = ProcessInfo.processInfo.environment
guard let premiseRoot = environment["PREMISE_ROOT"],
  let syntaxRoot = environment["SWIFT_SYNTAX_ROOT"]
else {
  fatalError("Run this fixture using scripts/test-macro-regression.sh")
}
let package = Package(
  name: "PremiseMacroRegression",
  dependencies: [
    .package(path: premiseRoot),
    .package(path: syntaxRoot),
  ],
  targets: [
    .macro(
      name: "PremiseMacrosPlugin",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
      ]
    ),
    .target(name: "PremiseMacros", dependencies: ["PremiseMacrosPlugin"]),
    .testTarget(
      name: "PremiseMacroRegressionTests",
      dependencies: [
        "PremiseMacros",
        .product(name: "PremiseCore", package: "Premise"),
        .product(name: "PremiseStrategies", package: "Premise"),
        .product(name: "PremiseTesting", package: "Premise"),
      ]
    ),
  ]
)
