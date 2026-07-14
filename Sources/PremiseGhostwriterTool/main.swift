import Foundation
import PremiseGhostwriter
import PremiseToolSupport

@main
struct PremiseGhostwriterTool {
  static func main() {
    do {
      let options = try GhostwriterOptions(arguments: Array(CommandLine.arguments.dropFirst()))
      if options.showHelp {
        try ToolIO.emit(helpText)
        return
      }

      let source = try PremiseGhostwriter.render(options.request)
      try ToolIO.emit(source)
    } catch {
      _ = try? ToolIO.logError("premise-ghostwriter: \(error)")
      _ = try? ToolIO.logError("Run `swift package premise-ghostwriter --help` for usage.")
      Foundation.exit(1)
    }
  }

  private static let helpText = """
    Usage:
      swift package premise-ghostwriter --kind fuzz-no-crash --module MyApp \\
        --type Payload --strategy 'Strategy<Payload>.payloads()' \\
        --subject 'try parse($0)'
      swift package premise-ghostwriter --kind roundtrip --module MyApp \\
        --type Payload --strategy 'Strategy<Payload>.payloads()' \\
        --encode 'try JSONEncoder().encode($0)' \\
        --decode 'try JSONDecoder().decode(Payload.self, from: $0)'
      swift package premise-ghostwriter --kind equivalence --module MyApp \\
        --type Payload --strategy 'Strategy<Payload>.payloads()' \\
        --subject 'try newImpl($0)' --alternate 'try oldImpl($0)'
      swift package premise-ghostwriter --kind idempotence --module MyApp \\
        --type Payload --strategy 'Strategy<Payload>.payloads()' \\
        --subject 'try normalize($0)'
      swift package premise-ghostwriter --kind binary-operation-laws --module MyApp \\
        --type Value --strategy 'Strategy<Value>.values()' \\
        --operation 'combine($0, $1)' --identity 'Value.empty'

    Options:
      --kind        One of: fuzz-no-crash (or fuzz), roundtrip, equivalence,
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

  private enum Option: String {
    case kind = "--kind"
    case module = "--module"
    case type = "--type"
    case strategy = "--strategy"
    case testName = "--test-name"
    case subject = "--subject"
    case alternate = "--alternate"
    case encode = "--encode"
    case decode = "--decode"
    case operation = "--operation"
    case identity = "--identity"
    case equality = "--equality"
  }

  init(arguments: [String]) throws {
    var values: [Option: String] = [:]
    var iterator = arguments.makeIterator()
    while let argument = iterator.next() {
      switch argument {
      case "--help", "-h":
        showHelp = true

      case let raw:
        guard let option = Option(rawValue: raw) else {
          throw GhostwriterCLIError.unknownArgument(raw)
        }
        values[option] = try Self.nextValue(&iterator, after: raw)
      }
    }

    request = showHelp ? Self.makeHelpPlaceholderRequest() : try Self.makeRequest(from: values)
  }

  // `--help` short-circuits rendering, but `request` is not optional; supply an
  // inert placeholder so the initializer stays total.
  private static func makeHelpPlaceholderRequest() -> GhostwriterRequest {
    GhostwriterRequest(
      kind: .fuzzNoCrash,
      moduleName: "ModuleUnderTest",
      typeName: "Value",
      strategyExpression: "Strategy<Value>.values()"
    )
  }

  private static func makeRequest(from values: [Option: String]) throws -> GhostwriterRequest {
    GhostwriterRequest(
      kind: try parseKind(require(values[.kind], .kind)),
      moduleName: try require(values[.module], .module),
      typeName: try require(values[.type], .type),
      strategyExpression: try require(values[.strategy], .strategy),
      testName: values[.testName],
      subjectExpression: values[.subject],
      alternateExpression: values[.alternate],
      encodeExpression: values[.encode],
      decodeExpression: values[.decode],
      operationExpression: values[.operation],
      identityExpression: values[.identity],
      equalityExpression: values[.equality] ?? "$0 == $1"
    )
  }

  private static func parseKind(_ rawValue: String) throws -> GhostwriterTemplateKind {
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
    guard let value = iterator.next() else {
      throw GhostwriterCLIError.missingValue(option)
    }
    return value
  }

  private static func require(_ value: String?, _ option: Option) throws -> String {
    guard let value else {
      throw GhostwriterCLIError.missingRequiredOption(option.rawValue)
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
