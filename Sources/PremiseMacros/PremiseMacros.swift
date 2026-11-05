// MARK: - @given macro

/// Declares a property test by attaching strategies to a plain function,
/// inspired by Hypothesis's `@given` decorator.
///
/// The macro generates a swift-testing `@Test` function that wraps the
/// annotated function body in a `forAll` call with the given strategies.
/// The number of strategy arguments must match the number of function
/// parameters.
///
/// ```swift
/// import PremiseMacros
/// import PremiseTesting
///
/// @given(.integers(in: 0...100), .ascii)
/// func additionIsCommutative(a: Int, s: String) {
///     #expect(s.count >= 0)
/// }
/// ```
///
/// The macro generates a peer type containing a Swift Testing test method.
/// Four or more strategies are combined with `zip`.
///
/// You can pass `config:`, `explicitExamples:`, and `examples:` labels after
/// the strategy arguments:
/// ```swift
/// @given(
///   .integers(in: 0...100),
///   config: .thorough,
///   explicitExamples: [0, 100],
///   examples: [.xfail(42, reason: "known bug")]
/// )
/// func largeSpace(n: Int) { ... }
/// ```
@attached(peer, names: suffixed(_Given))
public macro given(_ strategies: Any...) =
  #externalMacro(module: "PremiseMacrosPlugin", type: "GivenMacro")
