import PremiseStrategies

// Filter approach — works but wastes ~50% of draws.
let oddViaFilter = Strategy<Int>.integers(in: 1...99)
  .filter { $0 % 2 != 0 }

// Map approach — always produces odd numbers directly. Preferred.
let oddViaMap = Strategy<Int>.integers(in: 0...49)
  .map { $0 * 2 + 1 }

// Both produce odd integers, but the map version wastes no draws
// and produces a tighter distribution (always in 1, 3, 5, ... 99).
