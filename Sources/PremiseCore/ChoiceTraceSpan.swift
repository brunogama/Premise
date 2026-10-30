extension ChoiceTrace {
  /// A range of recorded choices.
  public struct Span: Sendable, Codable, Equatable {
    /// The optional span label.
    public var label: String?
    /// The inclusive start index.
    public var start: Int
    /// The exclusive end index.
    public var end: Int

    /// Creates a span with the given label and bounds.
    public init(label: String?, start: Int, end: Int) {
      self.label = label
      self.start = start
      self.end = end
    }

    /// Creates an unlabeled span with the given bounds.
    public init(start: Int, end: Int) {
      self.init(label: nil, start: start, end: end)
    }
  }
}
