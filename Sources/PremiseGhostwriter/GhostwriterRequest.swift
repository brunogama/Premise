/// Inputs used by ``PremiseGhostwriter`` to render Swift test skeletons.
public struct GhostwriterRequest: Sendable, Codable, Equatable {
  /// The template to render.
  public var kind: GhostwriterTemplateKind
  /// The module imported by the generated test.
  public var moduleName: String
  /// The name of the value type being tested.
  public var typeName: String
  /// Swift expression that constructs the input strategy.
  public var strategyExpression: String
  /// Optional name for the generated test function.
  public var testName: String?
  /// Optional operation or implementation under test.
  public var subjectExpression: String?
  /// Optional comparison implementation.
  public var alternateExpression: String?
  /// Optional encoding expression for round-trip tests.
  public var encodeExpression: String?
  /// Optional decoding expression for round-trip tests.
  public var decodeExpression: String?
  /// Optional binary operation expression.
  public var operationExpression: String?
  /// Optional identity value expression for binary operation laws.
  public var identityExpression: String?
  /// Expression comparing two generated values.
  public var equalityExpression: String

  /// Creates a request describing the template and its Swift expressions.
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
