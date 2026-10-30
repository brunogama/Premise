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
      return mutateBits(bitEntry, rng: &rng)
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

  private static func mutateBits(
    _ entry: ChoiceTrace.BitEntry,
    rng: inout TargetedMutationRNG
  ) -> ChoiceTrace.Entry {
    guard entry.count >= 1 else { return .bits(entry) }
    let bit = UInt64(rng.next() % UInt64(min(entry.count, UInt64.bitWidth)))
    let mask =
      entry.count >= UInt64.bitWidth
      ? UInt64.max
      : (UInt64(1) << UInt64(entry.count)) - 1
    let value = (entry.value ^ (UInt64(1) << bit)) & mask
    return .bits(ChoiceTrace.BitEntry(count: entry.count, value: value))
  }
}
