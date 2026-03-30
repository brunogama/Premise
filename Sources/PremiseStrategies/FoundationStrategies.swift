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
        return Character(UnicodeScalar(code)!)
      },
      shrink: { ch in
        guard ch != "a" else { return [] }
        return ["a"]
      }
    )
  }

  /// ASCII letters only (a-z, A-Z).
  static var letter: Strategy<Character> {
    let letters: [Character] = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    return Strategy<Character>(
      label: "character.letter",
      draw: { data in
        let index = data.drawInteger(in: 0...(letters.count - 1))
        return letters[index]
      },
      shrink: { ch in
        guard ch != "a" else { return [] }
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
        return Character(UnicodeScalar(code)!)
      },
      shrink: { ch in
        guard ch != "0" else { return [] }
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
        var scalar: UnicodeScalar?
        while scalar == nil {
          let raw = data.drawInteger(in: 0...0xFFFF)
          scalar = UnicodeScalar(raw)
        }
        return Character(scalar!)
      },
      shrink: { ch in
        guard ch != "a" else { return [] }
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
            var scalar: UnicodeScalar?
            while scalar == nil {
              let raw = data.drawInteger(in: 0...0xFFFF)
              scalar = UnicodeScalar(raw)
            }
            return Character(scalar!)
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
        let ti = try floatStrategy.draw(&data)
        return Date(timeIntervalSince1970: ti)
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
        let formatted = [
          String(hex.prefix(8)),
          String(hex.dropFirst(8).prefix(4)),
          String(hex.dropFirst(12).prefix(4)),
          String(hex.dropFirst(16).prefix(4)),
          String(hex.dropFirst(20)),
        ].joined(separator: "-")
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
        let schemeIndex = data.drawInteger(in: 0...(schemes.count - 1))
        let scheme = schemes[schemeIndex]

        let tlds = ["com", "org", "net", "io", "dev"]
        let tldIndex = data.drawInteger(in: 0...(tlds.count - 1))
        let tld = tlds[tldIndex]

        let hostChars: [Character] = Array("abcdefghijklmnopqrstuvwxyz")
        let hostLen = data.drawInteger(in: 3...12)
        let host = String(
          (0..<hostLen).map { _ in
            hostChars[data.drawInteger(in: 0...(hostChars.count - 1))]
          }
        )

        let pathSegments = data.drawInteger(in: 0...3)
        var path = ""
        for _ in 0..<pathSegments {
          let segLen = data.drawInteger(in: 1...8)
          let segment = String(
            (0..<segLen).map { _ in
              hostChars[data.drawInteger(in: 0...(hostChars.count - 1))]
            }
          )
          path += "/\(segment)"
        }

        return URL(string: "\(scheme)://\(host).\(tld)\(path)")
          ?? URL(string: "https://example.com")!
      },
      shrink: { _ in
        [URL(string: "https://a.com")!]
      }
    )
  }
}
