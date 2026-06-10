/// A high-scoring trace retained for targeted mutation.
struct TargetedTraceCandidate: Sendable, Equatable {
  var trace: ChoiceTrace
  var score: Double
}

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

/// Deterministically mutates traces while preserving trace structure.
enum TargetedTraceMutator {
  static func mutate(_ trace: ChoiceTrace, seed: UInt64) -> ChoiceTrace? {
    guard !trace.entries.isEmpty else { return nil }

    var rng = TargetedMutationRNG(seed: seed)
    var candidate = trace
    let index = Int(rng.next() % UInt64(candidate.entries.count))
    candidate.entries[index] = mutate(candidate.entries[index], rng: &rng)
    return candidate
  }

  private static func mutate(
    _ entry: ChoiceTrace.Entry,
    rng: inout TargetedMutationRNG
  ) -> ChoiceTrace.Entry {
    switch entry {
    case .bits(let bitEntry):
      guard bitEntry.count > 0 else { return entry }
      let bit = UInt64(rng.next() % UInt64(min(bitEntry.count, UInt64.bitWidth)))
      let mask =
        bitEntry.count >= UInt64.bitWidth
        ? UInt64.max
        : (UInt64(1) << UInt64(bitEntry.count)) - 1
      let value = (bitEntry.value ^ (UInt64(1) << bit)) & mask
      return .bits(ChoiceTrace.BitEntry(count: bitEntry.count, value: value))

    case .integer(let value):
      let delta = (rng.next() % 17) + 1
      if rng.next().isMultiple(of: 2) {
        return .integer(value &+ delta)
      }
      return .integer(value &- delta)

    case .boolean(let value):
      return .boolean(!value)

    case .bytes(let bytes):
      guard !bytes.isEmpty else { return entry }
      var updated = bytes
      let index = Int(rng.next() % UInt64(updated.count))
      updated[index] ^= UInt8(truncatingIfNeeded: rng.next())
      return .bytes(updated)
    }
  }
}

struct TargetedMutationRNG: Sendable {
  private var state: UInt64

  init(seed: UInt64) {
    self.state = seed == 0 ? 0x9e37_79b9_7f4a_7c15 : seed
  }

  mutating func next() -> UInt64 {
    state &+= 0x9e37_79b9_7f4a_7c15
    var z = state
    z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
    z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
    return z ^ (z >> 31)
  }
}
