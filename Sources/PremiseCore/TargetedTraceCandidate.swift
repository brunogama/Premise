/// A high-scoring trace retained for targeted mutation.
struct TargetedTraceCandidate: Sendable, Equatable {
  var trace: ChoiceTrace
  var score: Double
}
