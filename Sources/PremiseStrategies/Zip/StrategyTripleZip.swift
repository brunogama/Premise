import PremiseCore

/// Combines three strategies into a tuple and shrinks one component at a time.
public func zip<A: Sendable, B: Sendable, C: Sendable>(
  _ first: Strategy<A>,
  _ second: Strategy<B>,
  _ third: Strategy<C>
) -> Strategy<(A, B, C)> {
  Strategy<(A, B, C)>(
    label: "zip(\(first.label), \(second.label), \(third.label))",
    draw: { data in
      (try first.draw(&data), try second.draw(&data), try third.draw(&data))
    },
    shrink: { value in
      first.shrink(value.0).map { ($0, value.1, value.2) }
        + second.shrink(value.1).map { (value.0, $0, value.2) }
        + third.shrink(value.2).map { (value.0, value.1, $0) }
    }
  )
}
