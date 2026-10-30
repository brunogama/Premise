import PremiseCore
import PremiseStrategies

enum Alignment: Sendable { case left, center, right, justified }

// Generate each enum case with equal probability using oneOf + just.
let alignmentStrategy = Strategy<Alignment>.oneOf([
  .just(.left),
  .just(.center),
  .just(.right),
  .just(.justified),
])
