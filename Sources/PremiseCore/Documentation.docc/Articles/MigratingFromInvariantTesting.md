# Migrating from InvariantTesting

Premise keeps the same core habit as InvariantTesting: describe invariants and
let generated inputs search for counterexamples. The main differences are that
Premise records deterministic choice traces, shrinks failures structurally, and
replays persisted examples before fresh generation.

## Concept Mapping

| InvariantTesting concept | Premise concept |
| --- | --- |
| Arbitrary/generator | `Strategy<Value>` |
| Property/invariant | `forAll` or `premise_forAll` property closure |
| Assumption/precondition | `strategy.suchThat { ... }` or `strategy.assume { ... }` |
| Reproduction seed | `FailureRecord.seed` plus `ChoiceTrace` |
| Regression examples | committed replay corpus and local `.premise/examples` |
| Custom domain generator | `Strategy(label:draw:shrink:)` |
| Custom shrink behavior | `strategy.shrinking { ... }` |

## Typical Migration

1. Replace each generator with a `Strategy`.
2. Move invariant bodies into `forAll` for swift-testing or `premise_forAll` for
   XCTest.
3. Prefer constructive strategies over broad generation plus filtering.
4. Add custom shrinkers for domain objects whose smallest failing value is not
   obvious from scalar fields.
5. Commit important CI-discovered JSON trace artifacts into a replay corpus so
   they run before fresh generation.

## Example

```swift
import Testing
import PremiseTesting
import PremiseStrategies

@Test func normalizedScoresStayInRange() async throws {
  try await forAll(
    .arrays(of: .edgeCaseFloats(in: -10.0...10.0), minCount: 1, maxCount: 20)
  ) { scores in
    let normalized = normalize(scores)
    #expect(normalized.allSatisfy { (0.0...1.0).contains($0) })
  }
}
```

When the property fails, Premise reports a minimal counterexample, shrink
count, seed or replay trace, and enough property identity metadata to reproduce
the failure locally or in CI.
