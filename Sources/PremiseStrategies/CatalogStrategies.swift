import Foundation
import PremiseCore


// MARK: - Regex strings

public extension Strategy where Value == String {
  /// Generates strings that fully match a small, common regex subset.
  ///
  /// Supported generation syntax includes literals, `.`, character classes,
  /// escaped literals, and the quantifiers `?`, `*`, `+`, `{n}`, and `{m,n}`.
  /// Unsupported constructs are still validated by `NSRegularExpression`; if
  /// the generated subset cannot satisfy the full regex within `maxAttempts`,
  /// drawing throws a strategy exhaustion error.
  static func regex(
    _ pattern: String,
    length: ClosedRange<Int> = 0...128,
    maxAttempts: Int = 128
  ) -> Strategy<String> {
    Strategy<String>(
      label: "regex(\(pattern))",
      draw: { data in
        let (regex, plan) = try prepareRegex(pattern, length: length)

        for _ in 0..<maxAttempts {
          let candidate = plan.draw(using: &data)
          guard length.contains(candidate.count),
            regex.matchesEntire(candidate)
          else {
            continue
          }
          return candidate
        }

        throw StrategyError.filterExhausted(
          label: "regex(\(pattern))",
          maxAttempts: maxAttempts
        )
      },
      shrink: { value in shrinkRegex(value, length: length) }
    )
  }

  /// Generates identifier-shaped strings from caller-supplied character sets.
  static func identifiers(
    first: [Character],
    rest: [Character],
    length: ClosedRange<Int>
  ) -> Strategy<String> {
    validateIdentifier(first: first, rest: rest, length: length)
    return Strategy<String>(
      label: "identifiers(length: \(length))",
      draw: { data in
        let count = drawEdgeBiasedInteger(in: length, using: &data)
        var characters: [Character] = []
        characters.reserveCapacity(count)
        characters.append(first[data.drawInteger(in: 0...(first.count - 1))])
        for _ in 1..<count {
          characters.append(rest[data.drawInteger(in: 0...(rest.count - 1))])
        }
        return String(characters)
      },
      shrink: { value in
        shrinkIdentifier(value, first: first[0], length: length)
      }
    )
  }

  /// Generates C/Swift/SQL-safe ASCII identifier-shaped strings.
  static func asciiIdentifiers(length: ClosedRange<Int>) -> Strategy<String> {
    let first = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_")
    let rest = first + Array("0123456789")
    return identifiers(first: first, rest: rest, length: length)
  }

  /// Generates DNS-ish domain names.
  static func domainNames(
    labels: ClosedRange<Int> = 2...4,
    labelLength: ClosedRange<Int> = 1...12,
    topLevelDomains: [String] = ["com", "org", "net", "io", "dev"]
  ) -> Strategy<String> {
    validateDomain(labels: labels, topLevelDomains: topLevelDomains)
    return Strategy<String>(
      label: "domainNames(labels: \(labels))",
      draw: { data in
        let count = data.drawInteger(in: labels)
        let bodyCount = max(0, count - 1)
        var parts: [String] = []
        parts.reserveCapacity(count)
        for _ in 0..<bodyCount {
          parts.append(drawDomainLabel(length: labelLength, using: &data))
        }
        let tld = topLevelDomains[
          data.drawInteger(in: 0...(topLevelDomains.count - 1))
        ]
        parts.append(tld.lowercased())
        return parts.joined(separator: ".")
      },
      shrink: { value in shrinkDomain(value, labels: labels) }
    )
  }

  /// Generates simple RFC-5322-compatible email address strings.
  static func emailAddresses() -> Strategy<String> {
    Strategy<String>(
      label: "emailAddresses",
      draw: { data in
        let localChars = Array("abcdefghijklmnopqrstuvwxyz0123456789._%+-")
        let localLength = data.drawInteger(in: 1...20)
        let local = String(
          (0..<localLength).map { _ in
            localChars[data.drawInteger(in: 0...(localChars.count - 1))]
          }
        )
        let domain = try Strategy<String>.domainNames(labels: 2...3).draw(&data)
        return "\(local)@\(domain)"
      },
      shrink: { value in value == "a@example.com" ? [] : ["a@example.com"] }
    )
  }

  /// Generates IPv4 address strings.
  static func ipv4Addresses() -> Strategy<String> {
    Strategy<String>(
      label: "ipv4Addresses",
      draw: { data in
        (0..<4).map { _ in String(data.drawInteger(in: 0...255)) }
          .joined(separator: ".")
      },
      shrink: { value in value == "0.0.0.0" ? [] : ["0.0.0.0"] }
    )
  }

  /// Generates expanded IPv6 address strings.
  static func ipv6Addresses() -> Strategy<String> {
    Strategy<String>(
      label: "ipv6Addresses",
      draw: { data in
        (0..<8)
          .map { _ in String(data.drawInteger(in: 0...0xffff), radix: 16) }
          .joined(separator: ":")
      },
      shrink: { value in value == "::" ? [] : ["::"] }
    )
  }
}

private func validateDomain(
  labels: ClosedRange<Int>,
  topLevelDomains: [String]
) {
  precondition(labels.lowerBound >= 1, "domainNames labels must be positive")
  precondition(
    !topLevelDomains.isEmpty,
    "domainNames requires at least one TLD"
  )
}

private func shrinkRegex(
  _ value: String,
  length: ClosedRange<Int>
) -> [String] {
  guard !value.isEmpty else { return [] }
  return [String(value.dropLast())].filter { length.contains($0.count) }
}

private func shrinkDomain(
  _ value: String,
  labels: ClosedRange<Int>
) -> [String] {
  let parts = value.split(separator: ".").map(String.init)
  guard parts.count > labels.lowerBound else { return [] }
  return [parts.dropFirst().joined(separator: ".")]
}

private func validateIdentifier(
  first: [Character],
  rest: [Character],
  length: ClosedRange<Int>
) {
  precondition(
    !first.isEmpty,
    "identifiers(first:rest:length:) requires first characters"
  )
  precondition(
    length.lowerBound >= 1,
    "identifier length must include at least one character"
  )
  precondition(
    length.upperBound == 1 || !rest.isEmpty,
    "identifiers(first:rest:length:) requires rest characters "
      + "when length can exceed one"
  )
}

private func prepareRegex(
  _ pattern: String,
  length: ClosedRange<Int>
) throws -> (NSRegularExpression, RegexGenerationPlan) {
  do {
    let regex = try NSRegularExpression(pattern: pattern)
    let plan = try RegexGenerationPlan(
      pattern: pattern,
      maximumRepeat: max(1, length.upperBound)
    )
    return (regex, plan)
  } catch {
    throw StrategyError.invalidRegex(
      label: "regex(\(pattern))",
      reason: String(describing: error)
    )
  }
}

private func shrinkIdentifier(
  _ value: String,
  first: Character,
  length: ClosedRange<Int>
) -> [String] {
  guard !value.isEmpty else { return [] }
  var candidates: [String] = []
  let minimal = String(first)
  if value != minimal, length.contains(1) { candidates.append(minimal) }
  if value.count > length.lowerBound {
    candidates.append(String(value.dropLast()))
  }
  return uniqueStringCandidates(candidates.filter { length.contains($0.count) })
}

// MARK: - Private helpers


private func uniqueStringCandidates(_ candidates: [String]) -> [String] {
  var seen: Set<String> = []
  return candidates.filter { seen.insert($0).inserted }
}

private func drawDomainLabel(
  length: ClosedRange<Int>,
  using data: inout PremiseData
) -> String {
  let letters = Array("abcdefghijklmnopqrstuvwxyz")
  let body = Array("abcdefghijklmnopqrstuvwxyz0123456789-")
  let count = max(1, data.drawInteger(in: length))
  if count == 1 {
    return String(letters[data.drawInteger(in: 0...(letters.count - 1))])
  }
  var chars: [Character] = []
  chars.append(letters[data.drawInteger(in: 0...(letters.count - 1))])
  for _ in 0..<(count - 2) {
    chars.append(body[data.drawInteger(in: 0...(body.count - 1))])
  }
  chars.append(letters[data.drawInteger(in: 0...(letters.count - 1))])
  return String(chars)
}

private extension NSRegularExpression {
  func matchesEntire(_ value: String) -> Bool {
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    guard let match = firstMatch(in: value, range: range) else {
      return false
    }
    return match.range.location == range.location
      && match.range.length == range.length
  }
}
