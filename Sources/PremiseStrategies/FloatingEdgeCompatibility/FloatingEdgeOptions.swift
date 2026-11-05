struct FloatingEdgeOptions: Sendable {
  let includeNaN: Bool
  let includeInfinity: Bool
  let includeDenormals: Bool
  let pivot: Double?
}
