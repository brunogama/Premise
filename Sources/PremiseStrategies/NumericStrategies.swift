import PremiseCore

// MARK: - Signed integer strategies

public extension Strategy where Value == Int8 {
  static var any: Strategy<Int8> { integers(in: .min ... .max) }
  static func integers(in range: ClosedRange<Int8>) -> Strategy<Int8> {
    Strategy<Int8>(
      label: "int8(in: \(range))",
      draw: { data in
        Int8(
          truncatingIfNeeded: drawEdgeBiasedInteger(
            in: Int(range.lowerBound)...Int(range.upperBound),
            using: &data
          )
        )
      },
      shrink: { value in
        guard value != range.lowerBound else { return [] }
        return [range.lowerBound, 0].filter { range.contains($0) && $0 < value }
      }
    )
  }
}

public extension Strategy where Value == Int16 {
  static var any: Strategy<Int16> { integers(in: .min ... .max) }
  static func integers(in range: ClosedRange<Int16>) -> Strategy<Int16> {
    Strategy<Int16>(
      label: "int16(in: \(range))",
      draw: { data in
        Int16(
          truncatingIfNeeded: drawEdgeBiasedInteger(
            in: Int(range.lowerBound)...Int(range.upperBound),
            using: &data
          )
        )
      },
      shrink: { value in
        guard value != range.lowerBound else { return [] }
        return [range.lowerBound, 0].filter { range.contains($0) && $0 < value }
      }
    )
  }
}

public extension Strategy where Value == Int32 {
  static var any: Strategy<Int32> { integers(in: .min ... .max) }
  static func integers(in range: ClosedRange<Int32>) -> Strategy<Int32> {
    Strategy<Int32>(
      label: "int32(in: \(range))",
      draw: { data in
        Int32(
          truncatingIfNeeded: drawEdgeBiasedInteger(
            in: Int(range.lowerBound)...Int(range.upperBound),
            using: &data
          )
        )
      },
      shrink: { value in
        guard value != range.lowerBound else { return [] }
        return [range.lowerBound, 0].filter { range.contains($0) && $0 < value }
      }
    )
  }
}

public extension Strategy where Value == Int64 {
  static var any: Strategy<Int64> { integers(in: .min ... .max) }
  static func integers(in range: ClosedRange<Int64>) -> Strategy<Int64> {
    Strategy<Int64>(
      label: "int64(in: \(range))",
      draw: { data in
        let raw = drawEdgeBiasedInteger(in: UInt64(0)...UInt64.max, using: &data)
        return offsetSigned64(raw, into: range)
      },
      shrink: { value in
        guard value != range.lowerBound else { return [] }
        return [range.lowerBound, 0].filter { range.contains($0) && $0 < value }
      }
    )
  }
}

public extension Strategy where Value == Int {
  /// Any `Int` in the full representable range.
  static var any: Strategy<Int> { integers(in: .min ... .max) }
  /// Positive integers (1 ... Int.max).
  static var positive: Strategy<Int> { integers(in: 1 ... .max) }
  /// Negative integers (Int.min ... -1).
  static var negative: Strategy<Int> { integers(in: .min ... -1) }
  /// Non-negative integers (0 ... Int.max).
  static var nonNegative: Strategy<Int> { integers(in: 0 ... .max) }
  /// Non-zero integers (positive or negative).
  static var nonZero: Strategy<Int> { .oneOf([.positive, .negative]) }
}

// MARK: - Unsigned integer strategies

public extension Strategy where Value == UInt8 {
  static var any: Strategy<UInt8> { integers(in: .min ... .max) }
  static func integers(in range: ClosedRange<UInt8>) -> Strategy<UInt8> {
    Strategy<UInt8>(
      label: "uint8(in: \(range))",
      draw: { data in
        UInt8(
          drawEdgeBiasedInteger(
            in: UInt64(range.lowerBound)...UInt64(range.upperBound),
            using: &data
          )
        )
      },
      shrink: { value in
        guard value != range.lowerBound else { return [] }
        return [range.lowerBound, 0].filter { range.contains($0) && $0 < value }
      }
    )
  }
}

public extension Strategy where Value == UInt16 {
  static var any: Strategy<UInt16> { integers(in: .min ... .max) }
  static func integers(in range: ClosedRange<UInt16>) -> Strategy<UInt16> {
    Strategy<UInt16>(
      label: "uint16(in: \(range))",
      draw: { data in
        UInt16(
          drawEdgeBiasedInteger(
            in: UInt64(range.lowerBound)...UInt64(range.upperBound),
            using: &data
          )
        )
      },
      shrink: { value in
        guard value != range.lowerBound else { return [] }
        return [range.lowerBound, 0].filter { range.contains($0) && $0 < value }
      }
    )
  }
}

public extension Strategy where Value == UInt32 {
  static var any: Strategy<UInt32> { integers(in: .min ... .max) }
  static func integers(in range: ClosedRange<UInt32>) -> Strategy<UInt32> {
    Strategy<UInt32>(
      label: "uint32(in: \(range))",
      draw: { data in
        UInt32(
          drawEdgeBiasedInteger(
            in: UInt64(range.lowerBound)...UInt64(range.upperBound),
            using: &data
          )
        )
      },
      shrink: { value in
        guard value != range.lowerBound else { return [] }
        return [range.lowerBound, 0].filter { range.contains($0) && $0 < value }
      }
    )
  }
}

public extension Strategy where Value == UInt {
  static var any: Strategy<UInt> { integers(in: .min ... .max) }
  static func integers(in range: ClosedRange<UInt>) -> Strategy<UInt> {
    Strategy<UInt>(
      label: "uint(in: \(range))",
      draw: { data in
        UInt(
          drawEdgeBiasedInteger(
            in: UInt64(range.lowerBound)...UInt64(range.upperBound),
            using: &data
          )
        )
      },
      shrink: { value in
        guard value != range.lowerBound else { return [] }
        return [range.lowerBound, 0].filter { range.contains($0) && $0 < value }
      }
    )
  }
}

// MARK: - Float strategy

public extension Strategy where Value == Float {
  /// Any finite `Float` in the given range.
  static func floats(in range: ClosedRange<Float>) -> Strategy<Float> {
    Strategy<Float>(
      label: "float(in: \(range))",
      draw: { data in
        let d = drawEdgeBiasedFloat(
          in: Double(range.lowerBound)...Double(range.upperBound),
          using: &data
        )
        return Float(d)
      },
      shrink: { value in
        let candidates: [Float] = [range.lowerBound, 0, (range.lowerBound + value) / 2]
        return candidates.filter { range.contains($0) && $0 < value }
      }
    )
  }

  /// Any finite `Float` in the full representable range.
  static var finite: Strategy<Float> {
    floats(in: -.greatestFiniteMagnitude ... .greatestFiniteMagnitude)
  }

  /// Any `Float` including `nan`, `infinity`, and `-infinity`.
  static var any: Strategy<Float> {
    Strategy<Float>(
      label: "float.any",
      draw: { data in
        let chooser = data.drawInteger(in: 0...7)
        switch chooser {
        case 0: return .nan
        case 1: return .infinity
        case 2: return -.infinity
        case 3: return 0
        case 4: return .greatestFiniteMagnitude
        case 5: return -.greatestFiniteMagnitude

        default:
          let raw = UInt32(data.drawInteger(in: UInt64(0)...UInt64(UInt32.max)))
          return Float(bitPattern: raw)
        }
      },
      shrink: { value in
        guard value.isFinite else { return [0] }
        return [0, value / 2].filter { $0 != value }
      }
    )
  }
}

// MARK: - Double extended strategies

public extension Strategy where Value == Double {
  /// Any finite `Double` in the full representable range.
  static var finite: Strategy<Double> {
    floats(in: -.greatestFiniteMagnitude ... .greatestFiniteMagnitude)
  }

  /// Any `Double` including `nan`, `infinity`, and `-infinity`.
  static var any: Strategy<Double> {
    Strategy<Double>(
      label: "double.any",
      draw: { data in
        let chooser = data.drawInteger(in: 0...7)
        switch chooser {
        case 0: return .nan
        case 1: return .infinity
        case 2: return -.infinity
        case 3: return 0.0
        case 4: return -0.0
        case 5: return .greatestFiniteMagnitude
        case 6: return -.greatestFiniteMagnitude

        default:
          let raw = data.drawInteger(in: UInt64(0)...UInt64.max)
          return Double(bitPattern: raw)
        }
      },
      shrink: { value in
        guard value.isFinite else { return [0.0] }
        return [0.0, value / 2].filter { $0 != value }
      }
    )
  }

  /// Edge-biased `Double` generation with opt-in exceptional values.
  static func edgeCaseFloats(
    in range: ClosedRange<Double>,
    includeNaN: Bool = false,
    includeInfinity: Bool = false,
    includeDenormals: Bool = false,
    epsilonAround pivot: Double? = nil
  ) -> Strategy<Double> {
    Strategy<Double>(
      label: "edgeCaseFloats(in: \(range))",
      draw: { data in
        let candidates = doubleEdgeCandidates(
          in: range,
          includeNaN: includeNaN,
          includeInfinity: includeInfinity,
          includeDenormals: includeDenormals,
          epsilonAround: pivot
        )
        let edgePick = data.drawInteger(in: 0...3)
        if edgePick < 3, !candidates.isEmpty {
          let index = data.drawInteger(in: 0...(candidates.count - 1))
          return candidates[index]
        }
        return drawEdgeBiasedFloat(in: range, using: &data)
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
}

// MARK: - Private helpers

private func offsetSigned64(_ raw: UInt64, into range: ClosedRange<Int64>) -> Int64 {
  let lower = range.lowerBound
  let upper = range.upperBound
  if lower == .min, upper == .max { return Int64(bitPattern: raw) }
  let span = UInt64(bitPattern: upper &- lower)
  return lower &+ Int64(bitPattern: raw % (span &+ 1))
}

private func doubleEdgeCandidates(
  in range: ClosedRange<Double>,
  includeNaN: Bool,
  includeInfinity: Bool,
  includeDenormals: Bool,
  epsilonAround pivot: Double?
) -> [Double] {
  var candidates = [range.lowerBound, range.upperBound, 0.0]
    .filter { range.contains($0) }
  if includeNaN {
    candidates.append(.nan)
  }
  if includeInfinity {
    candidates.append(contentsOf: [.infinity, -.infinity])
  }
  if includeDenormals {
    candidates.append(
      contentsOf: [
        Double.leastNonzeroMagnitude,
        -Double.leastNonzeroMagnitude,
      ].filter { range.contains($0) }
    )
  }
  if let pivot {
    candidates.append(
      contentsOf: [
        pivot,
        pivot + Double.ulpOfOne,
        pivot - Double.ulpOfOne,
      ].filter { range.contains($0) }
    )
  }
  return candidates
}
