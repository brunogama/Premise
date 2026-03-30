// MARK: - RunNote

/// A single named observation collected during a property run.
public struct RunNote: Sendable, Equatable, Codable {
  /// A short label identifying what is being observed.
  public let label: String

  /// The observed value rendered as a string.
  public let value: String

  public init(label: String, value: String) {
    self.label = label
    self.value = value
  }
}

// MARK: - RunStatistics

/// Observations accumulated during a single property-run execution.
///
/// Statistics are populated via ``PremiseData/note(_:value:)``,
/// ``PremiseData/event(_:)``, and ``PremiseData/target(_:label:)``
/// inside the property body or strategy draw phase.  They are purely
/// informational and do not affect generation, replay, or shrinking.
///
/// ```swift
/// forAll(.integers(in: 0...100)) { n, data in
///     data.note("input", value: n)
///     data.event(n.isMultiple(of: 2) ? "even" : "odd")
///     data.target(Double(n), label: "magnitude")
///     #expect(n >= 0)
/// }
/// ```
public struct RunStatistics: Sendable, Equatable {
  /// Named observations from ``PremiseData/note(_:value:)`` calls.
  public var notes: [RunNote]

  /// Events collected via ``PremiseData/event(_:)`` calls.
  public var events: [String]

  /// Highest score hint from ``PremiseData/target(_:label:)`` calls.
  ///
  /// When multiple `target` calls are made in a single run, the maximum
  /// score is retained.  The engine uses this hint to guide corpus
  /// selection toward inputs that maximize coverage.
  public var targetScore: Double?

  public init() {
    notes = []
    events = []
    targetScore = nil
  }
}
