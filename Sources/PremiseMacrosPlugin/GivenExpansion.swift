import SwiftBasicFormat
import SwiftSyntax

struct GivenExpansion {
  private let function: FunctionDeclSyntax
  private let arguments: LabeledExprListSyntax

  init(function: FunctionDeclSyntax, arguments: LabeledExprListSyntax) throws {
    let strategies = Self.strategies(in: arguments)
    let parameters = function.signature.parameterClause.parameters
    guard strategies.count == parameters.count else {
      throw MacroError.arityMismatch(strategies: strategies.count, params: parameters.count)
    }
    guard function.body != nil else { throw MacroError.missingBody }
    self.function = function
    self.arguments = arguments
  }

  func declaration() -> DeclSyntax {
    let generated = StructDeclSyntax(
      name: .identifier(function.name.text.filter { $0 != "`" } + "_Given"),
      memberBlock: MemberBlockSyntax(members: [MemberBlockItemSyntax(decl: testMethod())])
    )
    return generated.formatted().cast(DeclSyntax.self)
  }

  private func testMethod() -> FunctionDeclSyntax {
    let signature = FunctionSignatureSyntax(
      parameterClause: FunctionParameterClauseSyntax(parameters: []),
      effectSpecifiers: FunctionEffectSpecifiersSyntax(
        asyncSpecifier: .keyword(.async),
        throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
      )
    )
    let statement = CodeBlockItemSyntax(item: .expr(ExprSyntax(propertyCall())))
    return FunctionDeclSyntax(
      attributes: [
        .attribute(AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier("Test"))))
      ],
      name: .identifier("test"),
      signature: signature,
      body: CodeBlockSyntax(statements: [statement])
    )
  }

  private func propertyCall() -> TryExprSyntax {
    let strategies = Self.strategies(in: arguments)
    let zipped = strategies.count > 3
    let valueName = uniqueValueName()
    let passedStrategies =
      zipped ? [LabeledExprSyntax(expression: zipCall(strategies))] : strategies
    let call = FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier("forAll")),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax(Self.commaSeparated(passedStrategies + metadata())),
      rightParen: .rightParenToken(),
      trailingClosure: closure(zipped: zipped, valueName: valueName)
    )
    return TryExprSyntax(expression: AwaitExprSyntax(expression: call))
  }

  private func closure(zipped: Bool, valueName: TokenSyntax) -> ClosureExprSyntax {
    let params = parameterNames()
    let names = zipped ? [valueName] : params
    let closureParameters = names.enumerated().map { index, name in
      ClosureParameterSyntax(
        firstName: name,
        trailingComma: index < names.count - 1 ? .commaToken() : nil
      )
    }
    let signature = ClosureSignatureSyntax(
      parameterClause: .parameterClause(
        ClosureParameterClauseSyntax(parameters: ClosureParameterListSyntax(closureParameters))
      )
    )
    var statements = Array(function.body?.statements ?? [])
    if zipped { statements.insert(tupleBinding(params, valueName: valueName), at: 0) }
    return ClosureExprSyntax(signature: signature, statements: CodeBlockItemListSyntax(statements))
  }

  private func tupleBinding(_ names: [TokenSyntax], valueName: TokenSyntax) -> CodeBlockItemSyntax {
    let elements = names.enumerated().map { index, name in
      TuplePatternElementSyntax(
        pattern: IdentifierPatternSyntax(identifier: name),
        trailingComma: index < names.count - 1 ? .commaToken() : nil
      )
    }
    let pattern = TuplePatternSyntax(elements: TuplePatternElementListSyntax(elements))
    let value = DeclReferenceExprSyntax(baseName: valueName)
    let binding = PatternBindingSyntax(
      pattern: pattern,
      initializer: InitializerClauseSyntax(value: value)
    )
    let declaration = VariableDeclSyntax(bindingSpecifier: .keyword(.let), bindings: [binding])
    return CodeBlockItemSyntax(item: .decl(DeclSyntax(declaration)))
  }

  private func parameterNames() -> [TokenSyntax] {
    function.signature.parameterClause.parameters.map { $0.secondName ?? $0.firstName }
  }

  private func uniqueValueName() -> TokenSyntax {
    let names = Set(function.tokens(viewMode: .sourceAccurate).map(\.text))
    var candidate = "premiseGeneratedValues"
    while names.contains(candidate) { candidate += "_" }
    return .identifier(candidate)
  }

  private func metadata() -> [LabeledExprSyntax] {
    ["config", "explicitExamples", "examples"].compactMap { label in
      arguments.last { $0.label?.text == label }
    }
  }

  private static func strategies(in arguments: LabeledExprListSyntax) -> [LabeledExprSyntax] {
    Array(
      arguments.filter { argument in
        !["config", "explicitExamples", "examples"].contains(argument.label?.text ?? "")
      }
    )
  }

  private func zipCall(_ strategies: [LabeledExprSyntax]) -> FunctionCallExprSyntax {
    FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier("zip")),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax(Self.commaSeparated(strategies)),
      rightParen: .rightParenToken()
    )
  }

  private static func commaSeparated(_ arguments: [LabeledExprSyntax]) -> [LabeledExprSyntax] {
    arguments.enumerated().map { index, argument in
      argument.with(\.trailingComma, index < arguments.count - 1 ? .commaToken() : nil)
    }
  }
}
