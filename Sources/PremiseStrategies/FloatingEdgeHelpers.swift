import PremiseCore
func makeFloatingEdgeStrategy(
  in range: ClosedRange<Double>,
  options: FloatingEdgeOptions
) -> Strategy<Double> {
  Strategy<Double>(
    label: "edgeCaseFloats(in: \(range))",
    draw: { data in
      drawFloatingEdge(in: range, options: options, using: &data)
    },
    shrink: { value in
      if value.isNaN || value.isInfinite {
        return [0.0].filter { range.contains($0) }
      }
      let candidates = [0.0, range.lowerBound, value / 2]
      return candidates.filter { range.contains($0) && $0 != value }
    }
  )
}
private func drawFloatingEdge(
  in range: ClosedRange<Double>,
  options: FloatingEdgeOptions,
  using data: inout PremiseData
) -> Double {
  let candidates = doubleEdgeCandidates(in: range, options: options)
  let edgePick = data.drawInteger(in: 0...3)
  if edgePick < 3, !candidates.isEmpty {
    let index = data.drawInteger(in: 0...(candidates.count - 1))
    return candidates[index]
  }
  return drawEdgeBiasedFloat(in: range, using: &data)
}
private func doubleEdgeCandidates(
  in range: ClosedRange<Double>,
  options: FloatingEdgeOptions
) -> [Double] {
  var candidates = finiteDoubleEdgeCandidates(in: range)
  candidates.append(
    contentsOf: exceptionalDoubleEdgeCandidates(
      includeNaN: options.includeNaN,
      includeInfinity: options.includeInfinity
    )
  )
  if options.includeDenormals {
    candidates.append(
      contentsOf: [
        Double.leastNonzeroMagnitude,
        -Double.leastNonzeroMagnitude,
      ].filter { range.contains($0) }
    )
  }
  candidates.append(
    contentsOf: pivotCandidates(in: range, pivot: options.pivot)
  )
  return candidates
}

private func pivotCandidates(
  in range: ClosedRange<Double>,
  pivot: Double?
) -> [Double] {
  guard let pivot else { return [] }
  return [pivot, pivot + Double.ulpOfOne, pivot - Double.ulpOfOne]
    .filter { range.contains($0) }
}
private func finiteDoubleEdgeCandidates(
  in range: ClosedRange<Double>
) -> [Double] {
  [range.lowerBound, range.upperBound, 0.0].filter { range.contains($0) }
}

private func exceptionalDoubleEdgeCandidates(
  includeNaN: Bool,
  includeInfinity: Bool
) -> [Double] {
  var candidates: [Double] = []
  if includeNaN {
    candidates.append(.nan)
  }
  if includeInfinity {
    candidates.append(contentsOf: [.infinity, -.infinity])
  }
  return candidates
}
