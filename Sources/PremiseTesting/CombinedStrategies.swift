#if canImport(Testing)
import PremiseCore

func combinedStrategy<A: Sendable, B: Sendable>(
  _ first: Strategy<A>,
  _ second: Strategy<B>
) -> Strategy<(A, B)> {
  Strategy<(A, B)>(
    label: "(\(first.label), \(second.label))",
    draw: { data in
      (try first.draw(&data), try second.draw(&data))
    },
    shrink: { pair in
      first.shrink(pair.0).map { ($0, pair.1) }
        + second.shrink(pair.1).map { (pair.0, $0) }
    }
  )
}

func combinedStrategy<A: Sendable, B: Sendable, C: Sendable>(
  _ first: Strategy<A>,
  _ second: Strategy<B>,
  _ third: Strategy<C>
) -> Strategy<(A, B, C)> {
  Strategy<(A, B, C)>(
    label: "(\(first.label), \(second.label), \(third.label))",
    draw: { data in
      (try first.draw(&data), try second.draw(&data), try third.draw(&data))
    },
    shrink: { triple in
      first.shrink(triple.0).map { ($0, triple.1, triple.2) }
        + second.shrink(triple.1).map { (triple.0, $0, triple.2) }
        + third.shrink(triple.2).map { (triple.0, triple.1, $0) }
    }
  )
}
#endif
