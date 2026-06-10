import Foundation

/// Premise ghostwriter templates for common property-test shapes.
public enum GhostwriterTemplateKind: String, CaseIterable, Sendable, Codable, Equatable {
  /// Generate a no-crash fuzzing skeleton around `fuzzOneInput`.
  case fuzzNoCrash = "fuzz-no-crash"
  /// Generate an encode/decode round-trip property.
  case roundtrip
  /// Generate a differential/equivalence property between two implementations.
  case equivalence
  /// Generate an idempotence property for a normalizer-like operation.
  case idempotence
  /// Generate commutativity, associativity, and optional identity checks.
  case binaryOperationLaws = "binary-operation-laws"
}

/// Inputs used by ``PremiseGhostwriter`` to render Swift test skeletons.
public struct GhostwriterRequest: Sendable, Codable, Equatable {
  public var kind: GhostwriterTemplateKind
  public var moduleName: String
  public var typeName: String
  public var strategyExpression: String
  public var testName: String?
  public var subjectExpression: String?
  public var alternateExpression: String?
  public var encodeExpression: String?
  public var decodeExpression: String?
  public var operationExpression: String?
  public var identityExpression: String?
  public var equalityExpression: String

  public init(
    kind: GhostwriterTemplateKind,
    moduleName: String,
    typeName: String,
    strategyExpression: String,
    testName: String? = nil,
    subjectExpression: String? = nil,
    alternateExpression: String? = nil,
    encodeExpression: String? = nil,
    decodeExpression: String? = nil,
    operationExpression: String? = nil,
    identityExpression: String? = nil,
    equalityExpression: String = "$0 == $1"
  ) {
    self.kind = kind
    self.moduleName = moduleName
    self.typeName = typeName
    self.strategyExpression = strategyExpression
    self.testName = testName
    self.subjectExpression = subjectExpression
    self.alternateExpression = alternateExpression
    self.encodeExpression = encodeExpression
    self.decodeExpression = decodeExpression
    self.operationExpression = operationExpression
    self.identityExpression = identityExpression
    self.equalityExpression = equalityExpression
  }
}

/// Errors produced while rendering ghostwriter templates.
public enum GhostwriterError: Error, Sendable, CustomStringConvertible, Equatable {
  case missingExpression(String)
  case unsupportedKind(String)

  public var description: String {
    switch self {
    case .missingExpression(let name):
      return "Missing required ghostwriter expression: \(name)."
    case .unsupportedKind(let kind):
      return "Unsupported ghostwriter template kind: \(kind)."
    }
  }
}

/// Renders Swift Testing property skeletons for common Premise workflows.
public enum PremiseGhostwriter {
  /// Generates a Swift source skeleton for the requested template.
  public static func render(_ request: GhostwriterRequest) throws -> String {
    switch request.kind {
    case .fuzzNoCrash:
      return renderFuzzNoCrash(request)
    case .roundtrip:
      return try renderRoundtrip(request)
    case .equivalence:
      return try renderEquivalence(request)
    case .idempotence:
      return try renderIdempotence(request)
    case .binaryOperationLaws:
      return try renderBinaryOperationLaws(request)
    }
  }

  /// Generates a no-crash fuzzing skeleton.
  public static func fuzzNoCrash(
    moduleName: String,
    typeName: String,
    strategyExpression: String,
    subjectExpression: String? = nil,
    testName: String? = nil
  ) -> String {
    renderFuzzNoCrash(
      GhostwriterRequest(
        kind: .fuzzNoCrash,
        moduleName: moduleName,
        typeName: typeName,
        strategyExpression: strategyExpression,
        testName: testName,
        subjectExpression: subjectExpression
      )
    )
  }

  /// Generates an encode/decode round-trip skeleton.
  public static func roundtrip(
    moduleName: String,
    typeName: String,
    strategyExpression: String,
    encodeExpression: String,
    decodeExpression: String,
    testName: String? = nil
  ) -> String {
    // Safe force-try: all required fields are supplied by this typed helper.
    try! render(
      GhostwriterRequest(
        kind: .roundtrip,
        moduleName: moduleName,
        typeName: typeName,
        strategyExpression: strategyExpression,
        testName: testName,
        encodeExpression: encodeExpression,
        decodeExpression: decodeExpression
      )
    )
  }

  /// Generates a differential/equivalence skeleton.
  public static func equivalence(
    moduleName: String,
    typeName: String,
    strategyExpression: String,
    subjectExpression: String,
    alternateExpression: String,
    testName: String? = nil
  ) -> String {
    try! render(
      GhostwriterRequest(
        kind: .equivalence,
        moduleName: moduleName,
        typeName: typeName,
        strategyExpression: strategyExpression,
        testName: testName,
        subjectExpression: subjectExpression,
        alternateExpression: alternateExpression
      )
    )
  }

  /// Generates an idempotence skeleton.
  public static func idempotence(
    moduleName: String,
    typeName: String,
    strategyExpression: String,
    subjectExpression: String,
    testName: String? = nil
  ) -> String {
    try! render(
      GhostwriterRequest(
        kind: .idempotence,
        moduleName: moduleName,
        typeName: typeName,
        strategyExpression: strategyExpression,
        testName: testName,
        subjectExpression: subjectExpression
      )
    )
  }

  /// Generates a binary operation law skeleton.
  public static func binaryOperationLaws(
    moduleName: String,
    typeName: String,
    strategyExpression: String,
    operationExpression: String,
    identityExpression: String? = nil,
    testName: String? = nil
  ) -> String {
    try! render(
      GhostwriterRequest(
        kind: .binaryOperationLaws,
        moduleName: moduleName,
        typeName: typeName,
        strategyExpression: strategyExpression,
        testName: testName,
        operationExpression: operationExpression,
        identityExpression: identityExpression
      )
    )
  }
}

private extension PremiseGhostwriter {
  static func renderFuzzNoCrash(_ request: GhostwriterRequest) -> String {
    let functionName = request.testName ?? "\(identifier(request.typeName))FuzzNoCrash"
    let subject = unaryStatement(
      request.subjectExpression,
      argument: "value",
      fallback: "_ = value"
    )

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

  static func renderRoundtrip(_ request: GhostwriterRequest) throws -> String {
    let encode = try required(request.encodeExpression, "encodeExpression")
    let decode = try required(request.decodeExpression, "decodeExpression")
    let functionName = request.testName ?? "\(identifier(request.typeName))RoundTrips"
    let encoded = expression(encode, arguments: ["value"])
    let decoded = expression(decode, arguments: ["encoded"])
    let equality = expression(request.equalityExpression, arguments: ["decoded", "value"])

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

  static func renderEquivalence(_ request: GhostwriterRequest) throws -> String {
    let primary = try required(request.subjectExpression, "subjectExpression")
    let alternate = try required(request.alternateExpression, "alternateExpression")
    let functionName = request.testName ?? "\(identifier(request.typeName))ImplementationsAgree"
    let lhs = expression(primary, arguments: ["value"])
    let rhs = expression(alternate, arguments: ["value"])
    let equality = expression(request.equalityExpression, arguments: ["lhs", "rhs"])

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

  static func renderIdempotence(_ request: GhostwriterRequest) throws -> String {
    let subject = try required(request.subjectExpression, "subjectExpression")
    let functionName = request.testName ?? "\(identifier(request.typeName))IsIdempotent"
    let once = expression(subject, arguments: ["value"])
    let twice = expression(subject, arguments: ["once"])
    let equality = expression(request.equalityExpression, arguments: ["twice", "once"])

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

  static func renderBinaryOperationLaws(_ request: GhostwriterRequest) throws -> String {
    let operation = try required(request.operationExpression, "operationExpression")
    let functionName = request.testName ?? "\(identifier(request.typeName))BinaryOperationLaws"
    let ab = expression(operation, arguments: ["a", "b"])
    let ba = expression(operation, arguments: ["b", "a"])
    let abThenC = expression(operation, arguments: ["ab", "c"])
    let bc = expression(operation, arguments: ["b", "c"])
    let aThenBC = expression(operation, arguments: ["a", "bc"])
    let equality = request.equalityExpression
    var identityChecks = ""

    if let identity = request.identityExpression, !identity.isEmpty {
      let leftIdentity = expression(operation, arguments: [identity, "a"])
      let rightIdentity = expression(operation, arguments: ["a", identity])
      identityChecks = """

            let leftIdentity = \(leftIdentity)
            let rightIdentity = \(rightIdentity)
            #expect(\(expression(equality, arguments: ["leftIdentity", "a"])))
            #expect(\(expression(equality, arguments: ["rightIdentity", "a"])))
        """
    }

    return header(request) + """

      @Test("\(request.typeName) binary operation laws")
      func \(functionName)() async throws {
        try await forAll(
          \(request.strategyExpression),
          \(request.strategyExpression),
          \(request.strategyExpression)
        ) { a, b, c in
          let ab = \(ab)
          let ba = \(ba)
          #expect(\(expression(equality, arguments: ["ab", "ba"])))

          let leftAssociated = \(abThenC)
          let bc = \(bc)
          let rightAssociated = \(aThenBC)
          #expect(\(expression(equality, arguments: ["leftAssociated", "rightAssociated"])))\(identityChecks)
        }
      }
      """
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
