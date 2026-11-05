struct DetailedPhaseInput<Value: Sendable> {
  let phase: PropertyPhase
  let cases: (examples: [ExplicitExample<Value>], traces: [ChoiceTrace])
}
