import Foundation
import PremiseGhostwriter

enum PremiseGhostwriterTool {
  static func main() {
    do {
      let arguments = Array(CommandLine.arguments.dropFirst())
      let options = try GhostwriterOptions(arguments: arguments)
      if options.showHelp {
        output(helpText)
        return
      }

      let source = try PremiseGhostwriter.render(options.request)
      output(source)
    } catch {
      fputs("premise-ghostwriter: \(error)\n", stderr)
      let usage = "Run `swift package premise-ghostwriter --help` for usage.\n"
      fputs(usage, stderr)
      Foundation.exit(1)
    }
  }

  private static func output(_ text: String) {
    FileHandle.standardOutput.write(Data((text + "\n").utf8))
  }

  private static let helpText = """
    Usage:
      swift package premise-ghostwriter --kind fuzz-no-crash --module MyApp \
    --type Payload --strategy 'Strategy<Payload>.payloads()' \
    --subject 'try parse($0)'
      swift package premise-ghostwriter --kind roundtrip --module MyApp \
    --type Payload --strategy 'Strategy<Payload>.payloads()' \
    --encode 'try JSONEncoder().encode($0)' \
    --decode 'try JSONDecoder().decode(Payload.self, from: $0)'
      swift package premise-ghostwriter --kind equivalence --module MyApp \
    --type Payload --strategy 'Strategy<Payload>.payloads()' \
    --subject 'try newImpl($0)' --alternate 'try oldImpl($0)'
      swift package premise-ghostwriter --kind idempotence --module MyApp \
    --type Payload --strategy 'Strategy<Payload>.payloads()' \
    --subject 'try normalize($0)'
      swift package premise-ghostwriter --kind binary-operation-laws \
    --module MyApp \
    --type Value --strategy 'Strategy<Value>.values()' \
    --operation 'combine($0, $1)' --identity 'Value.empty'

    Options:
      --kind        One of: fuzz-no-crash (or fuzz), roundtrip, equivalence, \
    idempotence, binary-operation-laws
      --module      Module under test imported with @testable import
      --type        Value type under test
      --strategy    Swift expression returning Strategy<T>
      --test-name   Optional generated test function name
      --subject     Primary unary expression using $0
      --alternate   Alternate unary expression using $0
      --encode      Round-trip encode expression using $0
      --decode      Round-trip decode expression using $0
      --operation   Binary operation expression using $0 and $1
      --identity    Optional identity value for binary-operation-laws
      --equality    Equality expression using $0 and $1 (default: $0 == $1)
    """
}

private struct GhostwriterOptions {
  var showHelp = false
  var request: GhostwriterRequest

  init(arguments: [String]) throws {
    var values: [String: String] = [:]
    var iterator = arguments.makeIterator()
    while let argument = iterator.next() {
      if argument == "--help" || argument == "-h" {
        showHelp = true
      } else {
        try Self.parse(argument, iterator: &iterator, values: &values)
      }
    }
    request = try Self.makeRequest(values: values, showHelp: showHelp)
  }

  private static let valueOptions: Set<String> = [
    "--kind", "--module", "--type", "--strategy", "--test-name", "--subject",
    "--alternate", "--encode", "--decode", "--operation", "--identity",
    "--equality",
  ]

  private static func parse(
    _ argument: String,
    iterator: inout Array<String>.Iterator,
    values: inout [String: String]
  ) throws {
    guard valueOptions.contains(argument) else {
      throw GhostwriterCLIError.unknownArgument(argument)
    }
    let value = try nextValue(&iterator, after: argument)
    if argument == "--kind" {
      _ = try parseKind(value)
    }
    values[argument] = value
  }

  private static let helpRequest = GhostwriterRequest(
    kind: .fuzzNoCrash,
    moduleName: "ModuleUnderTest",
    typeName: "Value",
    strategyExpression: "Strategy<Value>.values()"
  )
  private static func makeRequest(
    values: [String: String],
    showHelp: Bool
  ) throws -> GhostwriterRequest {
    if showHelp {
      return helpRequest
    }
    return GhostwriterRequest(
      kind: try parseKind(require(values["--kind"], "--kind")),
      moduleName: try require(values["--module"], "--module"),
      typeName: try require(values["--type"], "--type"),
      strategyExpression: try require(values["--strategy"], "--strategy"),
      testName: values["--test-name"],
      subjectExpression: values["--subject"],
      alternateExpression: values["--alternate"],
      encodeExpression: values["--encode"],
      decodeExpression: values["--decode"],
      operationExpression: values["--operation"],
      identityExpression: values["--identity"],
      equalityExpression: values["--equality"] ?? "$0 == $1"
    )
  }

  private static func parseKind(
    _ rawValue: String
  ) throws -> GhostwriterTemplateKind {
    if rawValue == "fuzz" { return .fuzzNoCrash }
    guard let kind = GhostwriterTemplateKind(rawValue: rawValue) else {
      throw GhostwriterCLIError.invalidKind(rawValue)
    }
    return kind
  }

  private static func nextValue(
    _ iterator: inout Array<String>.Iterator,
    after option: String
  ) throws -> String {
    guard let value = iterator.next(),
      !value.hasPrefix("--"), value != "-h"
    else {
      throw GhostwriterCLIError.missingValue(option)
    }
    return value
  }

  private static func require<Value>(
    _ value: Value?,
    _ option: String
  ) throws -> Value {
    guard let value else {
      throw GhostwriterCLIError.missingRequiredOption(option)
    }
    return value
  }
}

private enum GhostwriterCLIError: Error, CustomStringConvertible {
  case invalidKind(String)
  case missingRequiredOption(String)
  case missingValue(String)
  case unknownArgument(String)

  var description: String {
    switch self {
    case .invalidKind(let kind):
      return "Invalid template kind: \(kind)."
    case .missingRequiredOption(let option):
      return "Missing required option: \(option)."
    case .missingValue(let option):
      return "Missing value after option: \(option)."
    case .unknownArgument(let argument):
      return "Unknown argument: \(argument)."
    }
  }
}

PremiseGhostwriterTool.main()
