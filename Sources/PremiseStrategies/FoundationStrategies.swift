import PremiseCore
import Foundation

// MARK: - Character strategies

public extension Strategy where Value == Character {
  /// Printable ASCII characters (U+0020…U+007E).
  static var ascii: Strategy<Character> {
    Strategy<Character>(
      label: "character.ascii",
      draw: { data in
        let code = data.drawInteger(in: 32...126)
        return Character(UnicodeScalar(UInt8(code)))
      },
      shrink: { character in
        guard character != "a" else { return [] }
        return ["a"]
      }
    )
  }

  /// ASCII letters only (a-z, A-Z).
  static var letter: Strategy<Character> {
    let letters: [Character] =
      Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    return Strategy<Character>(
      label: "character.letter",
      draw: { data in
        let index = data.drawInteger(in: 0...(letters.count - 1))
        return letters[index]
      },
      shrink: { character in
        guard character != "a" else { return [] }
        return ["a"]
      }
    )
  }

  /// ASCII digits (0-9).
  static var digit: Strategy<Character> {
    Strategy<Character>(
      label: "character.digit",
      draw: { data in
        let code = data.drawInteger(in: 48...57)
        return Character(UnicodeScalar(UInt8(code)))
      },
      shrink: { character in
        guard character != "0" else { return [] }
        return ["0"]
      }
    )
  }

  /// Any Unicode scalar in the Basic Multilingual Plane (BMP), excluding
  /// surrogates.
  static var unicode: Strategy<Character> {
    Strategy<Character>(
      label: "character.unicode",
      draw: { data in
        // BMP: 0x0000–0xFFFF, excluding surrogates 0xD800–0xDFFF.
        return drawUnicodeCharacter(using: &data)
      },
      shrink: { character in
        guard character != "a" else { return [] }
        return ["a"]
      }
    )
  }
}

// MARK: - Unicode string strategies

public extension Strategy where Value == String {
  /// Generates strings containing arbitrary Unicode characters from the BMP.
  static var unicode: Strategy<String> {
    unicode(length: 0...100)
  }

  /// Generates Unicode strings of the given length range.
  static func unicode(length: ClosedRange<Int>) -> Strategy<String> {
    Strategy<String>(
      label: "unicode(length: \(length))",
      draw: { data in
        let count = drawEdgeBiasedInteger(in: length, using: &data)
        return String(
          (0..<count).map { _ -> Character in
            drawUnicodeCharacter(using: &data)
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
}

// MARK: - Data strategy

public extension Strategy where Value == Data {
  /// Generates binary data with exactly `length` bytes.
  static func data(length: Int) -> Strategy<Data> {
    precondition(length >= 0, "data length must be non-negative")
    return Strategy<Data>(
      label: "data(length: \(length))",
      draw: { premiseData in
        Data(premiseData.drawBytes(count: length))
      },
      shrink: { value in
        let zero = Data(repeating: 0, count: length)
        guard value.count == length, value != zero else { return [] }
        return [zero]
      }
    )
  }

  /// Generates binary data whose byte count is selected from `length`.
  static func data(length: ClosedRange<Int>) -> Strategy<Data> {
    precondition(length.lowerBound >= 0, "data length must be non-negative")
    return Strategy<Data>(
      label: "data(length: \(length))",
      draw: { premiseData in
        let count = drawEdgeBiasedInteger(in: length, using: &premiseData)
        return Data(premiseData.drawBytes(count: count))
      },
      shrink: { value in
        guard !value.isEmpty else { return [] }
        return [Data(value.dropLast()), Data()]
          .filter { length.contains($0.count) }
      }
    )
  }
}

// MARK: - Date strategy

public extension Strategy where Value == Date {
  /// Dates within the given interval, defaulting to ±50 years from now.
  static func dates(
    in range: ClosedRange<Date> = Date(
      timeIntervalSince1970: 0
    )...Date(timeIntervalSince1970: 4_102_444_800)
  ) -> Strategy<Date> {
    Strategy<Date>(
      label: "dates",
      draw: { data in
        let lowerTI = range.lowerBound.timeIntervalSince1970
        let upperTI = range.upperBound.timeIntervalSince1970
        let floatStrategy = Strategy<Double>.floats(in: lowerTI...upperTI)
        let interval = try floatStrategy.draw(&data)
        return Date(timeIntervalSince1970: interval)
      },
      shrink: { value in
        let epoch = Date(timeIntervalSince1970: 0)
        if range.contains(epoch), value != epoch {
          return [epoch]
        }
        return [range.lowerBound].filter { $0 != value }
      }
    )
  }

  /// Any date from Unix epoch (1970) to 2099-12-31.
  static var any: Strategy<Date> {
    dates()
  }
}

// MARK: - UUID strategy

public extension Strategy where Value == UUID {
  /// Generates random v4 UUIDs.
  static var any: Strategy<UUID> {
    Strategy<UUID>(
      label: "uuid",
      draw: { data in
        let bytes = data.drawBytes(count: 16)
        // Ensure v4 UUID format: version nibble = 4, variant bits = 10xx.
        var raw = bytes
        raw[6] = (raw[6] & 0x0F) | 0x40
        raw[8] = (raw[8] & 0x3F) | 0x80
        let hex = raw.map { String(format: "%02x", $0) }.joined()
        let first = String(hex.prefix(8))
        let second = String(hex.dropFirst(8).prefix(4))
        let third = String(hex.dropFirst(12).prefix(4))
        let fourth = String(hex.dropFirst(16).prefix(4))
        let fifth = String(hex.dropFirst(20))
        let formatted = [first, second, third, fourth, fifth]
          .joined(separator: "-")
        return UUID(uuidString: formatted) ?? UUID()
      },
      shrink: { _ in [] }
    )
  }
}

// MARK: - URL strategy

public extension Strategy where Value == URL {
  /// Generates HTTP/HTTPS URLs with random hosts and paths.
  static var http: Strategy<URL> {
    Strategy<URL>(
      label: "url.http",
      draw: { data in
        let schemes = ["http", "https"]
        let scheme = schemes[data.drawInteger(in: 0...(schemes.count - 1))]

        let tlds = ["com", "org", "net", "io", "dev"]
        let tldIndex = data.drawInteger(in: 0...(tlds.count - 1))
        let tld = tlds[tldIndex]

        let hostChars: [Character] = Array("abcdefghijklmnopqrstuvwxyz")
        let host = drawURLHost(using: &data, characters: hostChars)

        let path = drawURLPath(using: &data, characters: hostChars)

        guard
          let url = URL(string: "\(scheme)://\(host).\(tld)\(path)")
            ?? URL(string: "https://example.com")
        else {
          preconditionFailure("Invalid fallback URL")
        }
        return url
      },
      shrink: { _ in
        guard let url = URL(string: "https://a.com") else {
          preconditionFailure("Invalid shrink URL")
        }
        return [url]
      }
    )
  }
}

private func drawUnicodeCharacter(using data: inout PremiseData) -> Character {
  while true {
    let raw = data.drawInteger(in: 0...0xFFFF)
    if let scalar = UnicodeScalar(raw) {
      return Character(scalar)
    }
  }
}

private func drawURLHost(
  using data: inout PremiseData,
  characters: [Character]
) -> String {
  let length = data.drawInteger(in: 3...12)
  return String(
    (0..<length).map { _ in
      characters[data.drawInteger(in: 0...(characters.count - 1))]
    }
  )
}
private func drawURLPath(
  using data: inout PremiseData,
  characters: [Character]
) -> String {
  let pathSegments = data.drawInteger(in: 0...3)
  var path = ""
  for _ in 0..<pathSegments {
    let segmentLength = data.drawInteger(in: 1...8)
    let segment = String(
      (0..<segmentLength).map { _ in
        characters[data.drawInteger(in: 0...(characters.count - 1))]
      }
    )
    path += "/\(segment)"
  }
  return path
}
