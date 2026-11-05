import PremiseCore
struct RegexPiece: Sendable {
  var characters: [Character]
  var count: ClosedRange<Int>

  func draw(using data: inout PremiseData) -> String {
    let repeats = data.drawInteger(in: count)
    guard repeats > 0 else { return "" }
    return String(
      (0..<repeats).map { _ in
        characters[data.drawInteger(in: 0...(characters.count - 1))]
      }
    )
  }
}
