import PremiseCore

// MARK: - Integer strategies

public extension Strategy where Value == Int {
  static func integers(in range: ClosedRange<Int>) -> Strategy<Int> {
    Strategy<Int>(
      label: "integers(in: \(range))",
      draw: { data in
        drawEdgeBiasedInteger(in: range, using: &data)
      },
      shrink: { value in
        guard value != range.lowerBound else { return [] }
        let midpoint = range.lowerBound + ((value - range.lowerBound) / 2)
        let candidates = Set([range.lowerBound, 0, midpoint])
        return
          candidates
          .filter { range.contains($0) && $0 < value }
          .sorted()
      }
    )
  }
}

public extension Strategy where Value == UInt64 {
  static func integers(in range: ClosedRange<UInt64>) -> Strategy<UInt64> {
    Strategy<UInt64>(
      label: "integers(in: \(range))",
      draw: { data in
        drawEdgeBiasedInteger(in: range, using: &data)
      },
      shrink: { value in
        guard value != range.lowerBound else { return [] }
        let midpoint = range.lowerBound + ((value - range.lowerBound) / 2)
        let candidates = Set([range.lowerBound, 0, midpoint])
        return
          candidates
          .filter { range.contains($0) && $0 < value }
          .sorted()
      }
    )
  }
}

// MARK: - Boolean strategy

public extension Strategy where Value == Bool {
  static var booleans: Strategy<Bool> {
    Strategy<Bool>(
      label: "booleans",
      draw: { data in data.drawBoolean() },
      shrink: { value in value ? [false] : [] }
    )
  }
}

// MARK: - Double strategy

public extension Strategy where Value == Double {
  static func floats(in range: ClosedRange<Double>) -> Strategy<Double> {
    Strategy<Double>(
      label: "floats(in: \(range))",
      draw: { data in
        drawEdgeBiasedFloat(in: range, using: &data)
      },
      shrink: { value in
        let candidates = [range.lowerBound, 0, (range.lowerBound + value) / 2]
        return candidates.filter { range.contains($0) && $0 < value }
      }
    )
  }
}

// MARK: - Byte array strategies

public extension Strategy where Value == [UInt8] {
  static func bytes(length: Int) -> Strategy<[UInt8]> {
    Strategy<[UInt8]>(
      label: "bytes(length: \(length))",
      draw: { data in data.drawBytes(count: length) },
      shrink: { value in
        guard !value.isEmpty else { return [] }
        return [Array(value.dropLast())]
      }
    )
  }

  static func bytes(length: ClosedRange<Int>) -> Strategy<[UInt8]> {
    Strategy<[UInt8]>(
      label: "bytes(length: \(length))",
      draw: { data in
        let count = drawEdgeBiasedInteger(in: length, using: &data)
        return data.drawBytes(count: count)
      },
      shrink: { value in
        guard !value.isEmpty else { return [] }
        return [Array(value.dropLast()), []].filter { length.contains($0.count) }
      }
    )
  }
}

// MARK: - String strategies

public extension Strategy where Value == String {
  /// Generates strings built from a fixed character set.
  static func strings(
    from characters: [Character],
    length: ClosedRange<Int>
  ) -> Strategy<String> {
    precondition(!characters.isEmpty, "strings(from:length:) requires at least one character")
    return Strategy<String>(
      label: "strings(from: \(characters.count) chars, length: \(length))",
      draw: { data in
        let count = drawEdgeBiasedInteger(in: length, using: &data)
        return String(
          (0..<count).map { _ in
            characters[data.drawInteger(in: 0...(characters.count - 1))]
          }
        )
      },
      shrink: { value in
        guard !value.isEmpty else { return [] }
        return [String(value.dropLast())].filter { length.contains($0.count) }
      }
    )
  }

  /// Generates printable ASCII strings (characters U+0020…U+007E).
  static var ascii: Strategy<String> {
    ascii(length: 0...100)
  }

  /// Generates printable ASCII strings of the given length range.
  static func ascii(length: ClosedRange<Int>) -> Strategy<String> {
    Strategy<String>(
      label: "ascii(length: \(length))",
      draw: { data in
        let count = drawEdgeBiasedInteger(in: length, using: &data)
        return String(
          (0..<count).map { _ in
            let code = data.drawInteger(in: 32...126)
            return Character(UnicodeScalar(code)!)
          }
        )
      },
      shrink: { value in
        guard !value.isEmpty else { return [] }
        let shorter = String(value.dropLast())
        return [shorter].filter { length.contains($0.count) }
      }
    )
  }

  /// Generates strings containing only ASCII letters and digits.
  static var alphanumeric: Strategy<String> {
    alphanumeric(length: 0...50)
  }

  /// Generates alphanumeric strings of the given length range.
  static func alphanumeric(length: ClosedRange<Int>) -> Strategy<String> {
    let chars: [Character] =
      Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    return Strategy<String>(
      label: "alphanumeric(length: \(length))",
      draw: { data in
        let count = drawEdgeBiasedInteger(in: length, using: &data)
        return String(
          (0..<count).map { _ in
            chars[data.drawInteger(in: 0...(chars.count - 1))]
          }
        )
      },
      shrink: { value in
        guard !value.isEmpty else { return [] }
        return [String(value.dropLast())].filter { length.contains($0.count) }
      }
    )
  }
}

// MARK: - Optional strategy

public extension Strategy {
  func optional() -> Strategy<Value?> {
    Strategy<Value?>(
      label: "optional(\(label))",
      draw: { data in
        let useValue = try Strategy<Bool>.booleans.draw(&data)
        if useValue {
          return try self.draw(&data)
        }
        return nil
      },
      shrink: { value in
        guard let value else { return [] }
        return [nil] + self.shrink(value).map(Optional.some)
      }
    )
  }
}

// MARK: - Module-internal helpers (shared with NumericStrategies & FoundationStrategies)

func drawEdgeBiasedInteger<T: FixedWidthInteger & Sendable>(
  in range: ClosedRange<T>,
  using data: inout PremiseData
) -> T {
  let chooser = data.drawInteger(in: 0...4)
  switch chooser {
  case 0: return range.lowerBound
  case 1: return range.upperBound
  case 2 where range.contains(0): return 0

  default:
    let raw = data.drawInteger(in: UInt64(0)...UInt64.max)
    return offsetInteger(raw, into: range)
  }
}

func drawEdgeBiasedFloat(
  in range: ClosedRange<Double>,
  using data: inout PremiseData
) -> Double {
  let chooser = data.drawInteger(in: 0...4)
  switch chooser {
  case 0: return range.lowerBound
  case 1: return range.upperBound
  case 2 where range.contains(0): return 0
  case 3: return (range.lowerBound + range.upperBound) / 2

  default:
    let raw = Double(data.drawInteger(in: UInt64(0)...UInt64.max))
    let unit = raw / Double(UInt64.max)
    return range.lowerBound + (range.upperBound - range.lowerBound) * unit
  }
}

func offsetInteger<T: FixedWidthInteger>(
  _ raw: UInt64,
  into range: ClosedRange<T>
) -> T {
  if T.isSigned {
    let lower = Int64(truncatingIfNeeded: range.lowerBound)
    let upper = Int64(truncatingIfNeeded: range.upperBound)
    let span = UInt64(truncatingIfNeeded: upper &- lower)
    let value = lower &+ Int64(truncatingIfNeeded: raw % (span + 1))
    return T(truncatingIfNeeded: value)
  }
  let lower = UInt64(truncatingIfNeeded: range.lowerBound)
  let upper = UInt64(truncatingIfNeeded: range.upperBound)
  if lower == 0, upper == .max { return T(truncatingIfNeeded: raw) }
  let span = upper &- lower
  return T(truncatingIfNeeded: lower &+ (raw % (span + 1)))
}
