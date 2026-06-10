import Testing

@testable import PremiseGhostwriter

@Test("Ghostwriter renders fuzz no-crash skeleton")
func ghostwriterRendersFuzzNoCrashSkeleton() throws {
  let source = PremiseGhostwriter.fuzzNoCrash(
    moduleName: "ExampleApp",
    typeName: "Payload",
    strategyExpression: "Strategy<Payload>.payloads()",
    subjectExpression: "try parse($0)"
  )

  #expect(source.contains("@testable import ExampleApp"))
  #expect(source.contains("fuzzOneInput"))
  #expect(source.contains("try parse(value)"))
}

@Test("Ghostwriter renders roundtrip skeleton")
func ghostwriterRendersRoundtripSkeleton() throws {
  let source = PremiseGhostwriter.roundtrip(
    moduleName: "ExampleApp",
    typeName: "Payload",
    strategyExpression: "Strategy<Payload>.payloads()",
    encodeExpression: "try JSONEncoder().encode($0)",
    decodeExpression: "try JSONDecoder().decode(Payload.self, from: $0)"
  )

  #expect(source.contains("let encoded = try JSONEncoder().encode(value)"))
  #expect(source.contains("let decoded = try JSONDecoder().decode(Payload.self, from: encoded)"))
  #expect(source.contains("#expect(decoded == value)"))
}

@Test("Ghostwriter renders equivalence skeleton")
func ghostwriterRendersEquivalenceSkeleton() throws {
  let source = PremiseGhostwriter.equivalence(
    moduleName: "ExampleApp",
    typeName: "Payload",
    strategyExpression: "Strategy<Payload>.payloads()",
    subjectExpression: "try newImpl($0)",
    alternateExpression: "try oldImpl($0)"
  )

  #expect(source.contains("let lhs = try newImpl(value)"))
  #expect(source.contains("let rhs = try oldImpl(value)"))
  #expect(source.contains("#expect(lhs == rhs)"))
}

@Test("Ghostwriter renders idempotence skeleton")
func ghostwriterRendersIdempotenceSkeleton() throws {
  let source = PremiseGhostwriter.idempotence(
    moduleName: "ExampleApp",
    typeName: "Payload",
    strategyExpression: "Strategy<Payload>.payloads()",
    subjectExpression: "try normalize($0)"
  )

  #expect(source.contains("let once = try normalize(value)"))
  #expect(source.contains("let twice = try normalize(once)"))
  #expect(source.contains("#expect(twice == once)"))
}

@Test("Ghostwriter renders binary operation laws skeleton")
func ghostwriterRendersBinaryOperationLawsSkeleton() throws {
  let source = PremiseGhostwriter.binaryOperationLaws(
    moduleName: "ExampleApp",
    typeName: "Payload",
    strategyExpression: "Strategy<Payload>.payloads()",
    operationExpression: "combine($0, $1)",
    identityExpression: "Payload.empty"
  )

  #expect(source.contains("let ab = combine(a, b)"))
  #expect(source.contains("let ba = combine(b, a)"))
  #expect(source.contains("let leftIdentity = combine(Payload.empty, a)"))
  #expect(source.contains("let rightIdentity = combine(a, Payload.empty)"))
}

@Test("Ghostwriter reports missing required expressions")
func ghostwriterReportsMissingRequiredExpressions() throws {
  #expect(throws: GhostwriterError.missingExpression("encodeExpression")) {
    _ = try PremiseGhostwriter.render(
      GhostwriterRequest(
        kind: .roundtrip,
        moduleName: "ExampleApp",
        typeName: "Payload",
        strategyExpression: "Strategy<Payload>.payloads()"
      )
    )
  }
}
