import SwiftSyntax
import SwiftSyntaxMacros

/// `@given` is a peer macro inspired by Hypothesis's `@given` decorator.
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
/// Expands to:
/// ```swift
/// @Test func additionIsCommutative() async throws {
///     try await forAll(.integers(in: 0...100), .ascii) { a, s in
///         #expect(a >= 0)
///     }
/// }
/// ```
public struct GivenMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Must be attached to a function.
    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      throw MacroError.notAFunction
    }

    // Extract parameter names from the function signature.
    let params = funcDecl.signature.parameterClause.parameters
    let paramNames = params.map { param -> String in
      (param.secondName ?? param.firstName).text
    }

    // Extract strategy arguments from the @given attribute.
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
      throw MacroError.missingStrategies
    }

    // Separate config/example metadata from strategy args early so arity check is correct.
    var strategyExprs: [String] = []
    var configArg: String?
    var explicitExamplesArg: String?
    var examplesArg: String?

    for arg in arguments {
      switch arg.label?.text {
      case "config":
        configArg = arg.expression.trimmedDescription
      case "explicitExamples":
        explicitExamplesArg = arg.expression.trimmedDescription
      case "examples":
        examplesArg = arg.expression.trimmedDescription
      default:
        strategyExprs.append(arg.expression.trimmedDescription)
      }
    }

    // Validate arity matches.
    guard strategyExprs.count == paramNames.count else {
      throw MacroError.arityMismatch(
        strategies: strategyExprs.count,
        params: paramNames.count
      )
    }

    // Extract the function body.
    guard let body = funcDecl.body else {
      throw MacroError.missingBody
    }

    let funcName = funcDecl.name.text
    let bodyStatements = body.statements.trimmedDescription

    // Build the forAll call.
    let strategiesList = strategyExprs.joined(separator: ", ")
    let paramList = paramNames.joined(separator: ", ")

    var labeledArguments: [String] = []
    if let configArg {
      labeledArguments.append("config: \(configArg)")
    }
    if let explicitExamplesArg {
      labeledArguments.append("explicitExamples: \(explicitExamplesArg)")
    }
    if let examplesArg {
      labeledArguments.append("examples: \(examplesArg)")
    }

    let labeledPart =
      labeledArguments.isEmpty
      ? ""
      : ", \(labeledArguments.joined(separator: ", "))"

    let generated: DeclSyntax = """
      @Test func \(raw: funcName)() async throws {
          try await forAll(\(raw: strategiesList)\(raw: labeledPart)) { \(raw: paramList) in
              \(raw: bodyStatements)
          }
      }
      """

    return [generated]
  }
}

// MARK: - Errors

enum MacroError: Error, CustomStringConvertible {
  case notAFunction
  case missingStrategies
  case missingBody
  case arityMismatch(strategies: Int, params: Int)

  var description: String {
    switch self {
    case .notAFunction:
      return "@given can only be applied to functions"

    case .missingStrategies:
      return "@given requires at least one strategy argument"

    case .missingBody:
      return "@given requires a function with a body"

    case .arityMismatch(let s, let p):
      return "@given has \(s) strategies but function has \(p) parameters"
    }
  }
}
