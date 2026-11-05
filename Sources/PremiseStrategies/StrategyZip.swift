import PremiseCore
/// Combines two strategies into a tuple and shrinks one component at a time.
public func zip<A: Sendable, B: Sendable>(
  _ first: Strategy<A>,
  _ second: Strategy<B>
) -> Strategy<(A, B)> {
  Strategy<(A, B)>(
    label: "zip(\(first.label), \(second.label))",
    draw: { data in
      (try first.draw(&data), try second.draw(&data))
    },
    shrink: { value in
      first.shrink(value.0).map { ($0, value.1) }
        + second.shrink(value.1).map { (value.0, $0) }
    }
  )
}
/// Combines an arbitrary number of strategies into a tuple using Swift
/// parameter packs.
///
/// Each component is drawn independently and shrinking delegates to
/// trace-based ``/PremiseCore/ShrinkMachine`` (value-level shrinking is
/// not feasible across heterogeneous packs).
///
/// ```swift
/// let pair = zip(.integers(in: 0...10), Strategy<String>.ascii)
/// let triple = zip(.integers(in: 0...10), Strategy<Bool>.booleans, Strategy<String>.ascii)
/// ```
public func zip<each T: Sendable>(
  _ strategy: repeat Strategy<each T>
) -> Strategy<(repeat each T)> {
  let labels = packLabels(repeat each strategy)
  return Strategy<(repeat each T)>(
    label: "zip(\(labels))",
    draw: { data in
      (repeat try (each strategy).draw(&data))
    },
    // Value-level shrinking across parameter packs is not expressible;
    // trace-based ShrinkMachine handles minimisation.
    shrink: { _ in [] }
  )
}

// MARK: - Pack helpers

/// Collects strategy labels from a parameter pack into a comma-separated
/// string for diagnostics.
private func packLabels<each T: Sendable>(
  _ strategy: repeat Strategy<each T>
) -> String {
  var labels: [String] = []
  func append<S: Sendable>(_ strategy: Strategy<S>) {
    labels.append(strategy.label)
  }
  repeat append(each strategy)
  return labels.joined(separator: ", ")
}
