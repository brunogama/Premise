import Foundation
import PremiseCore

// MARK: - Catalog support types

/// A reduced rational-number value used by Premise's numeric strategies.
public struct PremiseRational: Sendable, Codable, Equatable, Hashable, CustomStringConvertible {
  /// Reduced signed numerator.
  public let numerator: Int

  /// Positive reduced denominator.
  public let denominator: Int

  /// Creates a reduced rational value from a numerator and non-zero denominator.
  public init(numerator: Int, denominator: Int) {
    precondition(denominator != 0, "PremiseRational denominator must be non-zero")
    let sign = denominator < 0 ? -1 : 1
    let divisor = greatestCommonDivisor(absClamped(numerator), absClamped(denominator))
    self.numerator = sign * (numerator / divisor)
    self.denominator = absClamped(denominator) / divisor
  }

  /// Textual `numerator/denominator` representation.
  public var description: String { "\(numerator)/\(denominator)" }
}

/// A simple complex-number value used by Premise's numeric strategies.
public struct PremiseComplex: Sendable, Codable, Equatable, CustomStringConvertible {
  /// Real component.
  public let real: Double

  /// Imaginary component.
  public let imaginary: Double

  /// Creates a complex number from real and imaginary components.
  public init(real: Double, imaginary: Double) {
    self.real = real
    self.imaginary = imaginary
  }

  /// Textual `real+imaginaryi` representation.
  public var description: String { "\(real)+\(imaginary)i" }
}

/// A deterministic generated function backed by a finite input/output table.
public struct GeneratedFunction<Input: Hashable & Sendable, Output: Sendable>: Sendable {
  /// Output returned for inputs that are absent from ``cases``.
  public let defaultOutput: Output

  /// Explicit input/output cases for this generated function.
  public let cases: [Input: Output]

  /// Creates a generated function from a default output and explicit cases.
  public init(defaultOutput: Output, cases: [Input: Output]) {
    self.defaultOutput = defaultOutput
    self.cases = cases
  }

  /// Returns the mapped output for `input`, or ``defaultOutput`` if absent.
  public func callAsFunction(_ input: Input) -> Output {
    cases[input] ?? defaultOutput
  }
}

// MARK: - Sampled values and enums

public extension Strategy {
  /// Chooses uniformly from a non-empty collection of fixed values.
  static func sampled<Values: Collection>(from values: Values) -> Strategy<Value>
  where Values.Element == Value {
    elements(of: Array(values))
  }

  /// Lazily resolves a strategy at draw time, supporting mutually-recursive definitions.
  static func deferred(
    label: String = "deferred",
    _ makeStrategy: @escaping @Sendable () -> Strategy<Value>
  ) -> Strategy<Value> {
    Strategy<Value>(
      label: label,
      draw: { data in try makeStrategy().draw(&data) },
      shrink: { value in makeStrategy().shrink(value) }
    )
  }

  /// Builds a custom strategy with direct access to `PremiseData`.
  static func composite(
    label: String = "composite",
    _ draw: @escaping @Sendable (inout PremiseData) throws -> Value,
    shrink: @escaping @Sendable (Value) -> [Value] = { _ in [] }
  ) -> Strategy<Value> {
    Strategy<Value>(label: label, draw: draw, shrink: shrink)
  }

  /// Draws one shared value and exposes it as a `just` strategy to a sub-strategy.
  ///
  /// This models Hypothesis-style shared values within a single generated example:
  /// every draw from the provided nested strategy sees the same value.
  static func shared<SharedValue: Sendable>(
    _ source: Strategy<SharedValue>,
    label: String = "shared",
    _ build: @escaping @Sendable (Strategy<SharedValue>) -> Strategy<Value>
  ) -> Strategy<Value> {
    Strategy<Value>(
      label: "\(label)(\(source.label))",
      draw: { data in
        let sharedValue = try source.draw(&data)
        return try build(.just(sharedValue)).draw(&data)
      },
      shrink: { _ in [] }
    )
  }
}


public extension Strategy
where Value: CaseIterable, Value.AllCases: Collection, Value.AllCases.Element == Value {
  /// Chooses from all cases of a `CaseIterable` value.
  static var cases: Strategy<Value> {
    elements(of: Array(Value.allCases))
  }
}

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
        let regex: NSRegularExpression
        let plan: RegexGenerationPlan
        do {
          regex = try NSRegularExpression(pattern: pattern)
          plan = try RegexGenerationPlan(pattern: pattern, maximumRepeat: max(1, length.upperBound))
        } catch {
          throw StrategyError.invalidRegex(
            label: "regex(\(pattern))",
            reason: String(describing: error)
          )
        }

        for _ in 0..<maxAttempts {
          let candidate = plan.draw(using: &data)
          guard length.contains(candidate.count), regex.matchesEntire(candidate) else {
            continue
          }
          return candidate
        }

        throw StrategyError.filterExhausted(label: "regex(\(pattern))", maxAttempts: maxAttempts)
      },
      shrink: { value in
        guard !value.isEmpty else { return [] }
        return [String(value.dropLast())].filter { length.contains($0.count) }
      }
    )
  }

  /// Generates identifier-shaped strings from caller-supplied character sets.
  static func identifiers(
    first: [Character],
    rest: [Character],
    length: ClosedRange<Int>
  ) -> Strategy<String> {
    precondition(!first.isEmpty, "identifiers(first:rest:length:) requires first characters")
    precondition(length.lowerBound >= 1, "identifier length must include at least one character")
    precondition(
      length.upperBound == 1 || !rest.isEmpty,
      "identifiers(first:rest:length:) requires rest characters when length can exceed one"
    )
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
        guard !value.isEmpty else { return [] }
        var candidates: [String] = []
        let minimal = String(first[0])
        if value != minimal, length.contains(1) {
          candidates.append(minimal)
        }
        if value.count > length.lowerBound {
          candidates.append(String(value.dropLast()))
        }
        return uniqueStringCandidates(candidates.filter { length.contains($0.count) })
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
    precondition(labels.lowerBound >= 1, "domainNames labels must be positive")
    precondition(!topLevelDomains.isEmpty, "domainNames requires at least one TLD")
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
        let tld = topLevelDomains[data.drawInteger(in: 0...(topLevelDomains.count - 1))]
        parts.append(tld.lowercased())
        return parts.joined(separator: ".")
      },
      shrink: { value in
        let parts = value.split(separator: ".").map(String.init)
        guard parts.count > labels.lowerBound else { return [] }
        return [parts.dropFirst().joined(separator: ".")]
      }
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
          (0..<localLength).map { _ in localChars[data.drawInteger(in: 0...(localChars.count - 1))]
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
        (0..<4).map { _ in String(data.drawInteger(in: 0...255)) }.joined(separator: ".")
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

// MARK: - URL strategies

public extension Strategy where Value == URL {
  /// Generates web URLs with optional ports, paths, and query items.
  static func web(
    schemes: [String] = ["http", "https"],
    allowPort: Bool = true,
    maxPathSegments: Int = 4,
    maxQueryItems: Int = 3
  ) -> Strategy<URL> {
    precondition(!schemes.isEmpty, "URL strategy requires at least one scheme")
    return Strategy<URL>(
      label: "url.web",
      draw: { data in
        var components = URLComponents()
        components.scheme = schemes[data.drawInteger(in: 0...(schemes.count - 1))]
        components.host = try Strategy<String>.domainNames().draw(&data)
        if allowPort, data.drawBoolean() {
          components.port = data.drawInteger(in: 1...65_535)
        }
        let pathCount = maxPathSegments <= 0 ? 0 : data.drawInteger(in: 0...maxPathSegments)
        if pathCount > 0 {
          let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789-_")
          components.path = (0..<pathCount).map { _ in
            let length = data.drawInteger(in: 1...12)
            return String(
              (0..<length).map { _ in chars[data.drawInteger(in: 0...(chars.count - 1))] }
            )
          }.joined(separator: "/", prefix: "/")
        }
        let queryCount = maxQueryItems <= 0 ? 0 : data.drawInteger(in: 0...maxQueryItems)
        if queryCount > 0 {
          components.queryItems = (0..<queryCount).map { index in
            URLQueryItem(name: "q\(index)", value: String(data.drawInteger(in: 0...999)))
          }
        }
        return components.url ?? URL(string: "https://example.com")!
      },
      shrink: { value in
        value.absoluteString == "https://example.com" ? [] : [URL(string: "https://example.com")!]
      }
    )
  }
}

// MARK: - Date, time, timezone, and calendar strategies

public extension Strategy where Value == TimeZone {
  static func timeZones(
    identifiers: [String] = TimeZone.knownTimeZoneIdentifiers
  ) -> Strategy<TimeZone> {
    let valid = identifiers.compactMap(TimeZone.init(identifier:))
    precondition(!valid.isEmpty, "timeZones requires at least one valid identifier")
    return Strategy<TimeZone>(
      label: "timeZones",
      draw: { data in valid[data.drawInteger(in: 0...(valid.count - 1))] },
      shrink: { zone in zone.identifier == "UTC" ? [] : [TimeZone(secondsFromGMT: 0)!] }
    )
  }
}

public extension Strategy where Value == Calendar.Identifier {
  static var calendarIdentifiers: Strategy<Calendar.Identifier> {
    .elements(of: [.gregorian, .iso8601, .buddhist, .hebrew, .islamic, .japanese])
  }
}

public extension Strategy where Value == DateComponents {
  static func dateTimes(
    years: ClosedRange<Int> = 1970...2099,
    timeZones: Strategy<TimeZone> = .timeZones()
  ) -> Strategy<DateComponents> {
    Strategy<DateComponents>(
      label: "dateTimes(years: \(years))",
      draw: { data in
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = try timeZones.draw(&data)
        components.year = data.drawInteger(in: years)
        components.month = data.drawInteger(in: 1...12)
        components.day = data.drawInteger(in: 1...28)
        components.hour = data.drawInteger(in: 0...23)
        components.minute = data.drawInteger(in: 0...59)
        components.second = data.drawInteger(in: 0...59)
        return components
      },
      shrink: { value in
        var epoch = DateComponents()
        epoch.calendar = Calendar(identifier: .gregorian)
        epoch.timeZone = TimeZone(secondsFromGMT: 0)
        epoch.year = max(years.lowerBound, 1970)
        epoch.month = 1
        epoch.day = 1
        epoch.hour = 0
        epoch.minute = 0
        epoch.second = 0
        return value == epoch ? [] : [epoch]
      }
    )
  }
}

public extension Strategy where Value == Double {
  /// Generates `TimeInterval`/duration values in seconds.
  static func timeIntervals(in range: ClosedRange<TimeInterval>) -> Strategy<TimeInterval> {
    Strategy<Double>.floats(in: range)
  }
}

public extension Strategy where Value == Duration {
  /// Generates Swift `Duration` values in whole seconds.
  static func durations(seconds range: ClosedRange<Int64>) -> Strategy<Duration> {
    Strategy<Duration>(
      label: "durations(seconds: \(range))",
      draw: { data in .seconds(try Strategy<Int64>.integers(in: range).draw(&data)) },
      shrink: { value in value == .zero ? [] : [.zero] }
    )
  }
}

// MARK: - UUID strategies

public extension Strategy where Value == UUID {
  /// The nil UUID (`00000000-0000-0000-0000-000000000000`).
  static var nilUUID: Strategy<UUID> {
    .just(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
  }

  /// Generates RFC 4122 version-4 UUIDs, optionally including nil UUIDs.
  static func version4(includeNil: Bool = false) -> Strategy<UUID> {
    includeNil ? .oneOf([.nilUUID, .any]) : .any
  }
}

// MARK: - Range, slice, and index strategies

public extension Strategy where Value == Int {
  /// Generates valid indices in `bounds`.
  static func indices(in bounds: Range<Int>) -> Strategy<Int> {
    precondition(!bounds.isEmpty, "indices(in:) requires a non-empty range")
    return .integers(in: bounds.lowerBound...(bounds.upperBound - 1))
  }
}

public extension Strategy where Value == Range<Int> {
  /// Generates half-open integer ranges contained in `bounds`.
  static func ranges(in bounds: Range<Int>) -> Strategy<Range<Int>> {
    precondition(bounds.lowerBound <= bounds.upperBound, "ranges(in:) requires ordered bounds")
    return Strategy<Range<Int>>(
      label: "ranges(in: \(bounds))",
      draw: { data in
        let start = data.drawInteger(in: bounds.lowerBound...bounds.upperBound)
        let end = data.drawInteger(in: start...bounds.upperBound)
        return start..<end
      },
      shrink: { value in
        value.isEmpty && value.lowerBound == bounds.lowerBound
          ? [] : [bounds.lowerBound..<bounds.lowerBound]
      }
    )
  }
}

public extension Strategy where Value == ClosedRange<Int> {
  /// Generates closed integer ranges contained in `bounds`.
  static func closedRanges(in bounds: ClosedRange<Int>) -> Strategy<ClosedRange<Int>> {
    Strategy<ClosedRange<Int>>(
      label: "closedRanges(in: \(bounds))",
      draw: { data in
        let start = data.drawInteger(in: bounds)
        let end = data.drawInteger(in: start...bounds.upperBound)
        return start...end
      },
      shrink: { value in
        value == bounds.lowerBound...bounds.lowerBound
          ? [] : [bounds.lowerBound...bounds.lowerBound]
      }
    )
  }
}

// MARK: - Decimal, rational, and complex numbers

public extension Strategy where Value == Decimal {
  /// Generates Decimal values by drawing an integer mantissa and decimal scale.
  static func decimals(
    mantissa: ClosedRange<Int> = -1_000_000...1_000_000,
    scale: ClosedRange<Int> = 0...6
  ) -> Strategy<Decimal> {
    Strategy<Decimal>(
      label: "decimals(mantissa: \(mantissa), scale: \(scale))",
      draw: { data in
        var value = Decimal(data.drawInteger(in: mantissa))
        let scaleValue = data.drawInteger(in: scale)
        if scaleValue > 0 {
          value /= Decimal(pow10(scaleValue))
        }
        return value
      },
      shrink: { value in value == 0 ? [] : [0] }
    )
  }
}

public extension Strategy where Value == PremiseRational {
  static func rationals(
    numerator: ClosedRange<Int> = -1_000...1_000,
    denominator: ClosedRange<Int> = 1...1_000
  ) -> Strategy<PremiseRational> {
    Strategy<PremiseRational>(
      label: "rationals",
      draw: { data in
        PremiseRational(
          numerator: data.drawInteger(in: numerator),
          denominator: max(1, data.drawInteger(in: denominator))
        )
      },
      shrink: { value in
        value == PremiseRational(numerator: 0, denominator: 1)
          ? [] : [PremiseRational(numerator: 0, denominator: 1)]
      }
    )
  }
}

public extension Strategy where Value == PremiseComplex {
  static func complexNumbers(
    real: ClosedRange<Double> = -1_000...1_000,
    imaginary: ClosedRange<Double> = -1_000...1_000
  ) -> Strategy<PremiseComplex> {
    Strategy<PremiseComplex>(
      label: "complexNumbers",
      draw: { data in
        PremiseComplex(
          real: try Strategy<Double>.floats(in: real).draw(&data),
          imaginary: try Strategy<Double>.floats(in: imaginary).draw(&data)
        )
      },
      shrink: { value in
        value == PremiseComplex(real: 0, imaginary: 0)
          ? [] : [PremiseComplex(real: 0, imaginary: 0)]
      }
    )
  }
}

// MARK: - Fixed dictionaries, records, and unique arrays

public extension Strategy {
  /// Generates a dictionary with a fixed key set and per-key value strategies.
  static func fixedDictionary<Key: Hashable & Sendable, Element: Sendable>(
    _ fields: [Key: Strategy<Element>]
  ) -> Strategy<[Key: Element]> {
    let orderedFields = fields.sorted { String(describing: $0.key) < String(describing: $1.key) }
    return Strategy<[Key: Element]>(
      label: "fixedDictionary(\(orderedFields.count) fields)",
      draw: { data in
        var result: [Key: Element] = [:]
        for (key, strategy) in orderedFields {
          result[key] = try strategy.draw(&data)
        }
        return result
      },
      shrink: { value in
        orderedFields.compactMap { key, strategy in
          guard let current = value[key], let shrunk = strategy.shrink(current).first else {
            return nil
          }
          var copy = value
          copy[key] = shrunk
          return copy
        }
      }
    )
  }

  /// Alias for string-keyed fixed dictionaries, useful for record-shaped payloads.
  static func record<Element: Sendable>(
    _ fields: [String: Strategy<Element>]
  ) -> Strategy<[String: Element]> {
    fixedDictionary(fields)
  }

  /// Generates arrays whose elements are unique by value.
  static func uniqueArrays<Element: Hashable & Sendable>(
    of element: Strategy<Element>,
    length: ClosedRange<Int>
  ) -> Strategy<[Element]> {
    arrays(of: element, length: length, uniqueBy: { $0 })
  }

  /// Generates arrays whose elements are unique according to `key`.
  static func arrays<Element: Sendable, Key: Hashable & Sendable>(
    of element: Strategy<Element>,
    length: ClosedRange<Int>,
    uniqueBy key: @escaping @Sendable (Element) -> Key
  ) -> Strategy<[Element]> {
    precondition(length.lowerBound >= 0, "array length must be non-negative")
    return Strategy<[Element]>(
      label: "arrays(of: \(element.label), length: \(length), uniqueBy: key)",
      draw: { data in
        let count = drawEdgeBiasedInteger(in: length, using: &data)
        var values: [Element] = []
        var seen: Set<Key> = []
        let maxAttempts = max(32, count * 16)
        for _ in 0..<maxAttempts where values.count < count {
          let candidate = try element.draw(&data)
          if seen.insert(key(candidate)).inserted {
            values.append(candidate)
          }
        }
        guard values.count == count else {
          throw StrategyError.filterExhausted(
            label: "unique array elements for \(element.label)",
            maxAttempts: maxAttempts
          )
        }
        return values
      },
      shrink: { value in
        guard !value.isEmpty, value.count > length.lowerBound else { return [] }
        return [Array(value.dropLast())].filter { length.contains($0.count) }
      }
    )
  }
}

// MARK: - Generated functions

public extension Strategy {
  /// Generates deterministic function-like values from sampled input/output cases.
  static func generatedFunctions<Input: Hashable & Sendable, Output: Sendable>(
    inputs: Strategy<Input>,
    outputs: Strategy<Output>,
    tableSize: ClosedRange<Int> = 0...8
  ) -> Strategy<GeneratedFunction<Input, Output>> {
    Strategy<GeneratedFunction<Input, Output>>(
      label: "generatedFunctions(inputs: \(inputs.label), outputs: \(outputs.label))",
      draw: { data in
        let defaultOutput = try outputs.draw(&data)
        let count = drawEdgeBiasedInteger(in: tableSize, using: &data)
        var cases: [Input: Output] = [:]
        let maxAttempts = max(32, count * 16)
        for _ in 0..<maxAttempts where cases.count < count {
          cases[try inputs.draw(&data)] = try outputs.draw(&data)
        }
        return GeneratedFunction(defaultOutput: defaultOutput, cases: cases)
      },
      shrink: { _ in [] }
    )
  }
}

// MARK: - Private helpers

private struct RegexGenerationPlan: Sendable {
  var pieces: [RegexPiece]

  init(pattern: String, maximumRepeat: Int) throws {
    var parser = RegexPatternParser(pattern: pattern, maximumRepeat: maximumRepeat)
    self.pieces = try parser.parse()
  }

  func draw(using data: inout PremiseData) -> String {
    pieces.map { $0.draw(using: &data) }.joined()
  }
}

private struct RegexPiece: Sendable {
  var characters: [Character]
  var count: ClosedRange<Int>

  func draw(using data: inout PremiseData) -> String {
    let repeats = data.drawInteger(in: count)
    guard repeats > 0 else { return "" }
    return String(
      (0..<repeats).map { _ in characters[data.drawInteger(in: 0...(characters.count - 1))] }
    )
  }
}

private struct RegexPatternParser {
  let characters: [Character]
  let maximumRepeat: Int
  var index = 0

  init(pattern: String, maximumRepeat: Int) {
    self.characters = Array(pattern)
    self.maximumRepeat = max(1, maximumRepeat)
  }

  mutating func parse() throws -> [RegexPiece] {
    var pieces: [RegexPiece] = []
    while index < characters.count {
      if characters[index] == "^" || characters[index] == "$" {
        index += 1
        continue
      }
      var piece = try parseAtom()
      if index < characters.count, let range = parseQuantifier() {
        piece.count = range
      }
      pieces.append(piece)
    }
    return pieces
  }

  private mutating func parseAtom() throws -> RegexPiece {
    let current = characters[index]
    index += 1

    switch current {
    case ".":
      return RegexPiece(characters: printableASCIICharacters, count: 1...1)
    case "[":
      return RegexPiece(characters: try parseCharacterClass(), count: 1...1)
    case "\\":
      guard index < characters.count else {
        throw StrategyError.invalidRegex(label: "regex", reason: "dangling escape")
      }
      let escaped = characters[index]
      index += 1
      switch escaped {
      case "d": return RegexPiece(characters: Array("0123456789"), count: 1...1)
      case "w":
        return RegexPiece(
          characters: Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"),
          count: 1...1
        )
      case "s": return RegexPiece(characters: [" ", "\t"], count: 1...1)
      default: return RegexPiece(characters: [escaped], count: 1...1)
      }
    case "(", ")", "|":
      throw StrategyError.invalidRegex(
        label: "regex",
        reason: "groups and alternation are not generated by this strategy"
      )
    default:
      return RegexPiece(characters: [current], count: 1...1)
    }
  }

  private mutating func parseCharacterClass() throws -> [Character] {
    var result: [Character] = []
    var previous: Character?
    var negate = false
    if index < characters.count, characters[index] == "^" {
      negate = true
      index += 1
    }

    while index < characters.count {
      let current = characters[index]
      index += 1
      if current == "]" {
        if negate {
          let excluded = Set(result.map(String.init))
          let remaining = printableASCIICharacters.filter { !excluded.contains(String($0)) }
          return remaining.isEmpty ? printableASCIICharacters : remaining
        }
        return result.isEmpty ? printableASCIICharacters : result
      }

      if current == "-", let previous, index < characters.count, characters[index] != "]" {
        let end = characters[index]
        index += 1
        result.append(contentsOf: asciiRange(from: previous, through: end))
      } else {
        result.append(current)
        previous = current
      }
    }

    throw StrategyError.invalidRegex(label: "regex", reason: "unterminated character class")
  }

  private mutating func parseQuantifier() -> ClosedRange<Int>? {
    switch characters[index] {
    case "?":
      index += 1
      return 0...1
    case "*":
      index += 1
      return 0...maximumRepeat
    case "+":
      index += 1
      return 1...maximumRepeat
    case "{":
      return parseBraceQuantifier()
    default:
      return nil
    }
  }

  private mutating func parseBraceQuantifier() -> ClosedRange<Int>? {
    let start = index
    index += 1
    var content = ""
    while index < characters.count, characters[index] != "}" {
      content.append(characters[index])
      index += 1
    }
    guard index < characters.count, characters[index] == "}" else {
      index = start
      return nil
    }
    index += 1

    let parts = content.split(separator: ",", omittingEmptySubsequences: false)
    if parts.count == 1, let exact = Int(parts[0]) {
      return exact...exact
    }
    if parts.count == 2, let lower = Int(parts[0]) {
      let upper = parts[1].isEmpty ? min(maximumRepeat, lower + 8) : (Int(parts[1]) ?? lower)
      return lower...max(lower, min(upper, maximumRepeat))
    }
    index = start
    return nil
  }
}

private let printableASCIICharacters: [Character] = (32...126).compactMap {
  UnicodeScalar($0).map(Character.init)
}

private func asciiRange(from start: Character, through end: Character) -> [Character] {
  guard let first = start.unicodeScalars.first?.value,
    let last = end.unicodeScalars.first?.value,
    first <= last,
    first < 128,
    last < 128
  else {
    return [start, end]
  }
  return (first...last).compactMap { UnicodeScalar($0).map(Character.init) }
}

private func uniqueStringCandidates(_ candidates: [String]) -> [String] {
  var seen: Set<String> = []
  return candidates.filter { seen.insert($0).inserted }
}

private func drawDomainLabel(length: ClosedRange<Int>, using data: inout PremiseData) -> String {
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
    return match.range.location == range.location && match.range.length == range.length
  }
}

private func pow10(_ exponent: Int) -> Int {
  guard exponent > 0 else { return 1 }
  return (0..<min(exponent, 18)).reduce(1) { value, _ in value * 10 }
}

private func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
  var a = max(1, lhs)
  var b = max(1, rhs)
  while b != 0 {
    let remainder = a % b
    a = b
    b = remainder
  }
  return max(1, a)
}

private func absClamped(_ value: Int) -> Int {
  value == Int.min ? Int.max : abs(value)
}

private extension Sequence where Element == String {
  func joined(separator: String, prefix: String) -> String {
    let body = joined(separator: separator)
    return body.isEmpty ? "" : prefix + body
  }
}
