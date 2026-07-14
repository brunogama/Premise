import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import PremiseMacrosPlugin

/// Expansion tests for the `@given` peer macro.
///
/// XCTest is required here: swift-syntax's `assertMacroExpansion` reports
/// through XCTest and only builds when the source-macro manifest is active
/// (`PREMISE_MACRO_SOURCE=1`).
final class GivenMacroTests: XCTestCase {
  private let macros: [String: Macro.Type] = ["given": GivenMacro.self]

  func testExpandsSingleStrategyProperty() {
    assertMacroExpansion(
      """
      @given(.integers(in: 0...100))
      func nonNegative(n: Int) {
          #expect(n >= 0)
      }
      """,
      expandedSource: """
        func nonNegative(n: Int) {
            #expect(n >= 0)
        }

        @Test func nonNegative() async throws {
            try await forAll(.integers(in: 0 ... 100)) { n in
                #expect(n >= 0)
            }
        }
        """,
      macros: macros
    )
  }

  func testExpandsMultipleStrategiesAndSecondNames() {
    assertMacroExpansion(
      """
      @given(.integers(in: 0...100), .ascii)
      func combines(_ count: Int, text: String) {
          #expect(count >= 0)
      }
      """,
      expandedSource: """
        func combines(_ count: Int, text: String) {
            #expect(count >= 0)
        }

        @Test func combines() async throws {
            try await forAll(.integers(in: 0 ... 100), .ascii) { count, text in
                #expect(count >= 0)
            }
        }
        """,
      macros: macros
    )
  }

  func testForwardsConfigLabel() {
    assertMacroExpansion(
      """
      @given(.bools, config: .fast)
      func configured(b: Bool) {
          #expect(b || !b)
      }
      """,
      expandedSource: """
        func configured(b: Bool) {
            #expect(b || !b)
        }

        @Test func configured() async throws {
            try await forAll(.bools, config: .fast) { b in
                #expect(b || !b)
            }
        }
        """,
      macros: macros
    )
  }

  func testForwardsExampleLabels() {
    assertMacroExpansion(
      """
      @given(.bools, explicitExamples: [1], examples: [.xfail(2)])
      func exampled(b: Bool) {
          #expect(b || !b)
      }
      """,
      expandedSource: """
        func exampled(b: Bool) {
            #expect(b || !b)
        }

        @Test func exampled() async throws {
            try await forAll(.bools, explicitExamples: [1], examples: [.xfail(2)]) { b in
                #expect(b || !b)
            }
        }
        """,
      macros: macros
    )
  }

  func testRejectsArityMismatch() {
    assertMacroExpansion(
      """
      @given(.integers(in: 0...100))
      func twoParams(a: Int, b: Int) {
          #expect(a >= 0)
      }
      """,
      expandedSource: """
        func twoParams(a: Int, b: Int) {
            #expect(a >= 0)
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@given has 1 strategies but function has 2 parameters",
          line: 1,
          column: 1
        )
      ],
      macros: macros
    )
  }

  func testRejectsNonFunctionAttachment() {
    assertMacroExpansion(
      """
      @given(.integers(in: 0...100))
      struct NotAFunction {}
      """,
      expandedSource: """
        struct NotAFunction {}
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@given can only be applied to functions",
          line: 1,
          column: 1
        )
      ],
      macros: macros
    )
  }

  func testRejectsMissingStrategies() {
    assertMacroExpansion(
      """
      @given
      func noStrategies(n: Int) {
          #expect(n >= 0)
      }
      """,
      expandedSource: """
        func noStrategies(n: Int) {
            #expect(n >= 0)
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@given requires at least one strategy argument",
          line: 1,
          column: 1
        )
      ],
      macros: macros
    )
  }
}
