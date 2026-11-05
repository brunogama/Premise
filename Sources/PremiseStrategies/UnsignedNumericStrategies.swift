import PremiseCore
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
