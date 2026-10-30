import SwiftSyntax
import SwiftSyntaxMacros

/// `@given` is a peer macro inspired by Hypothesis's `@given` decorator.
///
/// It generates a swift-testing `@Test` function wrapping the annotated
/// function body in a `forAll` call with the provided strategies.
///
/// Usage:
/// ```swift
/// @given(.integers(in: 0...100), .ascii)
/// func additionIsCommutative(a: Int, s: String) {
///     #expect(a >= 0)
/// }
/// ```
///
/// The generated test is a method on a peer type so Swift Testing can discover
/// it. Four or more strategies are combined into a tuple using `zip`.
public struct GivenMacro: PeerMacro {
  /// Builds a peer test declaration for the annotated property function.
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let function = declaration.as(FunctionDeclSyntax.self) else {
      throw MacroError.notAFunction
    }
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
      throw MacroError.missingStrategies
    }
    let expansion = try GivenExpansion(function: function, arguments: arguments)
    return [expansion.declaration()]
  }
}
