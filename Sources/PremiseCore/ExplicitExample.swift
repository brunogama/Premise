/// Expectation attached to an explicit example.
public enum ExplicitExampleExpectation: Sendable, Equatable, Codable {
  /// The example is expected to satisfy the property.
  case expectedToPass

  /// The example is expected to fail the property.
  ///
  /// Expected-failing examples are useful for checking that a property is
  /// capable of detecting a known bad input while still allowing generated
  /// exploration to continue afterward.
  case expectedToFail(reason: String? = nil)
}

/// A caller-provided example that runs before replay and generation.
///
/// Plain values can still be passed to `explicitExamples:`. Use
/// ``ExplicitExample`` when an example needs metadata such as an origin label
/// or expected-failure behavior.
public struct ExplicitExample<Value: Sendable>: Sendable {
  /// Value passed to the property body.
  public var value: Value

  /// Optional origin label for diagnostics and tooling.
  public var label: String?

  /// Whether this explicit example should pass or fail.
  public var expectation: ExplicitExampleExpectation

  /// Creates an explicit example.
  public init(
    _ value: Value,
    label: String? = nil,
    expectation: ExplicitExampleExpectation = .expectedToPass
  ) {
    self.value = value
    self.label = label
    self.expectation = expectation
  }

  /// Creates an expected-passing explicit example.
  public static func example(
    _ value: Value,
    label: String? = nil
  ) -> Self {
    Self(value, label: label, expectation: .expectedToPass)
  }

  /// Creates an expected-failing explicit example.
  public static func xfail(
    _ value: Value,
    reason: String? = nil,
    label: String? = nil
  ) -> Self {
    Self(value, label: label, expectation: .expectedToFail(reason: reason))
  }

  /// Returns a copy with an origin label.
  public func via(_ label: String) -> Self {
    var copy = self
    copy.label = label
    return copy
  }

  /// Returns a copy marked as expected to fail.
  public func xfail(reason: String? = nil) -> Self {
    var copy = self
    copy.expectation = .expectedToFail(reason: reason)
    return copy
  }
}
