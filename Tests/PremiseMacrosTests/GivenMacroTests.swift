import Foundation
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import PremiseMacrosPlugin

@Test func testExpandsSingleStrategyProperty() throws {
  try assertGivenExpansion("testExpandsSingleStrategyProperty")
}

@Test func testExpandsMultipleStrategiesAndSecondNames() throws {
  try assertGivenExpansion("testExpandsMultipleStrategiesAndSecondNames")
}

@Test func testForwardsConfigLabel() throws {
  try assertGivenExpansion("testForwardsConfigLabel")
}

@Test func testForwardsExampleLabels() throws {
  try assertGivenExpansion("testForwardsExampleLabels")
}

@Test func testRejectsArityMismatch() throws {
  try assertGivenExpansion(
    "testRejectsArityMismatch",
    diagnostics: [
      DiagnosticSpec(
        message: "@given has 1 strategies but function has 2 parameters",
        line: 1,
        column: 1
      )
    ]
  )
}

@Test func testRejectsNonFunctionAttachment() throws {
  try assertGivenExpansion(
    "testRejectsNonFunctionAttachment",
    diagnostics: [
      DiagnosticSpec(
        message: "@given can only be applied to functions",
        line: 1,
        column: 1
      )
    ]
  )
}

@Test func testRejectsMissingStrategies() throws {
  try assertGivenExpansion(
    "testRejectsMissingStrategies",
    diagnostics: [
      DiagnosticSpec(
        message: "@given requires at least one strategy argument",
        line: 1,
        column: 1
      )
    ]
  )
}

private func assertGivenExpansion(
  _ name: String,
  diagnostics: [DiagnosticSpec] = []
) throws {
  assertMacroExpansion(
    try expansionFixture(name, kind: "input"),
    expandedSource: try expansionFixture(name, kind: "expanded"),
    diagnostics: diagnostics,
    macroSpecs: ["given": .init(type: GivenMacro.self)],
    failureHandler: { Issue.record(Comment(rawValue: $0.message)) }
  )
}

private func expansionFixture(_ name: String, kind: String) throws -> String {
  let url = try #require(
    Bundle.module.url(
      forResource: name,
      withExtension: "\(kind).txt",
      subdirectory: "Fixtures"
    )
  )
  return try String(contentsOf: url, encoding: .utf8)
}
