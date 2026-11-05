struct ReplayOptions {
  var emitJSON = false
  var showHelp = false
  var blob: String?
  var input: String?

  init(arguments: [String]) throws {
    var iterator = arguments.makeIterator()
    while let argument = iterator.next() {
      try consume(argument, iterator: &iterator)
    }
  }

  private mutating func consume(
    _ argument: String,
    iterator: inout IndexingIterator<[String]>
  ) throws {
    switch argument {
    case "--help", "-h": showHelp = true
    case "--json": emitJSON = true
    case "--blob":
      guard let next = iterator.next() else {
        throw ReplayToolError.missingBlob
      }
      blob = next
    default:
      guard input == nil else { throw ReplayToolError.tooManyInputs }
      input = argument
    }
  }
}
