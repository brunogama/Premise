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
  /// - Throws: `GhostwriterError.missingExpression` for an empty encode or decode expression.
  public static func roundtrip(
    moduleName: String,
    typeName: String,
    strategyExpression: String,
    encodeExpression: String,
    decodeExpression: String,
    testName: String? = nil
  ) throws -> String {
    try render(
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
  /// - Throws: `GhostwriterError.missingExpression` for an empty subject or alternate expression.
  public static func equivalence(
    moduleName: String,
    typeName: String,
    strategyExpression: String,
    subjectExpression: String,
    alternateExpression: String,
    testName: String? = nil
  ) throws -> String {
    try render(
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
  /// - Throws: `GhostwriterError.missingExpression` for an empty subject expression.
  public static func idempotence(
    moduleName: String,
    typeName: String,
    strategyExpression: String,
    subjectExpression: String,
    testName: String? = nil
  ) throws -> String {
    try render(
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
  /// - Throws: `GhostwriterError.missingExpression` for an empty operation expression.
  public static func binaryOperationLaws(
    moduleName: String,
    typeName: String,
    strategyExpression: String,
    operationExpression: String,
    identityExpression: String? = nil,
    testName: String? = nil
  ) throws -> String {
    try render(
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
