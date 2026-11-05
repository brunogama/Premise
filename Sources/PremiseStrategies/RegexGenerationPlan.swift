import PremiseCore
struct RegexGenerationPlan: Sendable {
  private var pieces: [RegexPiece]

  init(pattern: String, maximumRepeat: Int) throws {
    var parser = RegexPatternParser(
      pattern: pattern,
      maximumRepeat: maximumRepeat
    )
    self.pieces = try parser.parse()
  }

  func draw(using data: inout PremiseData) -> String {
    pieces.map { $0.draw(using: &data) }.joined()
  }
}
