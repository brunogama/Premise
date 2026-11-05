/// Small deterministic corpus used by the `.target` phase.
struct TargetedTraceCorpus: Sendable {
  private(set) var best: TargetedTraceCandidate?

  mutating func record(trace: ChoiceTrace, statistics: RunStatistics) {
    guard let score = statistics.targetScore, score.isFinite else {
      return
    }
    if let current = best, current.score >= score {
      return
    }
    best = TargetedTraceCandidate(trace: trace, score: score)
  }

  func mutation(seed: UInt64, iteration: Int) -> ChoiceTrace? {
    guard let best else { return nil }
    return TargetedTraceMutator.mutate(
      best.trace,
      seed: seed &+ UInt64(iteration)
    )
  }
}
