import Foundation

extension PremiseGhostwriter {
  static func renderFuzzNoCrash(_ request: GhostwriterRequest) -> String {
    let functionName = request.testName ?? "\(identifier(request.typeName))FuzzNoCrash"
    let subject = fuzzSubject(request)

    return header(request) + """

      @Test("\(request.typeName) fuzz input does not crash")
      func \(functionName)() async throws {
        let corpus: [Data] = [Data()]

        for input in corpus {
          _ = try await fuzzOneInput(
            input,
            strategy: \(request.strategyExpression)
          ) { value in
            \(subject)
          }
        }
      }
      """
  }

  static func fuzzSubject(_ request: GhostwriterRequest) -> String {
    unaryStatement(
      request.subjectExpression,
      argument: "value",
      fallback: "_ = value"
    )
  }

  static func renderRoundtrip(_ request: GhostwriterRequest) throws -> String {
    let encode = try required(request.encodeExpression, "encodeExpression")
    let decode = try required(request.decodeExpression, "decodeExpression")
    let functionName = request.testName ?? "\(identifier(request.typeName))RoundTrips"
    let encoded = expression(encode, arguments: ["value"])
    let decoded = expression(decode, arguments: ["encoded"])
    let equality = expression(
      request.equalityExpression,
      arguments: ["decoded", "value"]
    )

    return header(request) + """

      @Test("\(request.typeName) round trips")
      func \(functionName)() async throws {
        try await forAll(\(request.strategyExpression)) { value in
          let encoded = \(encoded)
          let decoded = \(decoded)
          #expect(\(equality))
        }
      }
      """
  }

  static func renderEquivalence(
    _ request: GhostwriterRequest
  ) throws -> String {
    let primary = try required(request.subjectExpression, "subjectExpression")
    let alternate = try required(
      request.alternateExpression,
      "alternateExpression"
    )
    return equivalenceTemplate(request, primary: primary, alternate: alternate)
  }

  static func equivalenceTemplate(
    _ request: GhostwriterRequest,
    primary: String,
    alternate: String
  ) -> String {
    let functionName =
      request.testName ?? "\(identifier(request.typeName))ImplementationsAgree"
    let lhs = expression(primary, arguments: ["value"])
    let rhs = expression(alternate, arguments: ["value"])
    let equality = expression(
      request.equalityExpression,
      arguments: ["lhs", "rhs"]
    )

    return header(request) + """

      @Test("\(request.typeName) implementations agree")
      func \(functionName)() async throws {
        try await forAll(\(request.strategyExpression)) { value in
          let lhs = \(lhs)
          let rhs = \(rhs)
          #expect(\(equality))
        }
      }
      """
  }

  static func renderIdempotence(
    _ request: GhostwriterRequest
  ) throws -> String {
    let subject = try required(request.subjectExpression, "subjectExpression")
    let functionName = request.testName ?? "\(identifier(request.typeName))IsIdempotent"
    let once = expression(subject, arguments: ["value"])
    let twice = expression(subject, arguments: ["once"])
    let equality = expression(
      request.equalityExpression,
      arguments: ["twice", "once"]
    )

    return header(request) + """

      @Test("\(request.typeName) operation is idempotent")
      func \(functionName)() async throws {
        try await forAll(\(request.strategyExpression)) { value in
          let once = \(once)
          let twice = \(twice)
          #expect(\(equality))
        }
      }
      """
  }

  static func renderBinaryOperationLaws(
    _ request: GhostwriterRequest
  ) throws -> String {
    let operation = try required(
      request.operationExpression,
      "operationExpression"
    )
    let functionName =
      request.testName
      ?? "\(identifier(request.typeName))BinaryOperationLaws"

    return header(request) + """

      @Test("\(request.typeName) binary operation laws")
      func \(functionName)() async throws {
        try await forAll(
          \(request.strategyExpression),
          \(request.strategyExpression),
          \(request.strategyExpression)
        ) { a, b, c in
      \(binaryOperationBody(request, operation: operation))
        }
      }
      """
  }

  static func binaryOperationBody(
    _ request: GhostwriterRequest,
    operation: String
  ) -> String {
    let left = expression(operation, arguments: ["ab", "c"])
    let right = expression(operation, arguments: ["a", "bc"])
    let commutative = expression(
      request.equalityExpression,
      arguments: ["ab", "ba"]
    )
    let associative = expression(
      request.equalityExpression,
      arguments: ["leftAssociated", "rightAssociated"]
    )
    return [
      "    let ab = \(expression(operation, arguments: ["a", "b"]))",
      "    let ba = \(expression(operation, arguments: ["b", "a"]))",
      "    #expect(\(commutative))",
      "",
      "    let leftAssociated = \(left)",
      "    let bc = \(expression(operation, arguments: ["b", "c"]))",
      "    let rightAssociated = \(right)",
      "    #expect(\(associative))\(binaryIdentityChecks(request, operation: operation))",
    ].joined(separator: "\n")
  }

  static func binaryIdentityChecks(
    _ request: GhostwriterRequest,
    operation: String
  ) -> String {
    guard let identity = request.identityExpression, !identity.isEmpty else {
      return ""
    }
    let leftIdentity = expression(operation, arguments: [identity, "a"])
    let rightIdentity = expression(operation, arguments: ["a", identity])
    let equality = request.equalityExpression
    return [
      "",
      "    let leftIdentity = \(leftIdentity)",
      "    let rightIdentity = \(rightIdentity)",
      "    #expect(\(expression(equality, arguments: ["leftIdentity", "a"])))",
      "    #expect(\(expression(equality, arguments: ["rightIdentity", "a"])))",
    ].joined(separator: "\n")
  }

  static func header(_ request: GhostwriterRequest) -> String {
    """
    import Foundation
    import Testing
    import PremiseCore
    import PremiseFuzzing
    import PremiseStrategies
    import PremiseTesting
    @testable import \(request.moduleName)
    """
  }

  static func required(_ value: String?, _ name: String) throws -> String {
    guard let value, !value.isEmpty else {
      throw GhostwriterError.missingExpression(name)
    }
    return value
  }

  static func unaryStatement(
    _ template: String?,
    argument: String,
    fallback: String
  ) -> String {
    guard let template, !template.isEmpty else { return fallback }
    return expression(template, arguments: [argument])
  }

  static func expression(_ template: String, arguments: [String]) -> String {
    var rendered = template
    for (index, argument) in arguments.enumerated() {
      rendered = rendered.replacingOccurrences(of: "$\(index)", with: argument)
    }
    return rendered
  }

  static func identifier(_ text: String) -> String {
    let scalars = text.unicodeScalars.map { scalar in
      CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "_"
    }
    let raw = String(scalars)
    guard let first = raw.first else { return "generatedProperty" }
    if first.isNumber {
      return "_\(raw)"
    }
    return raw.prefix(1).lowercased() + raw.dropFirst()
  }
}
