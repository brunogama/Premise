/// Premise ghostwriter templates for common property-test shapes.
public enum GhostwriterTemplateKind:
  String, CaseIterable, Sendable, Codable, Equatable
{
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
