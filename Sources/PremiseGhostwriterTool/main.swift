import Foundation
import PremiseGhostwriter

@main
struct PremiseGhostwriterTool {
  static func main() {
    do {
      let options = try GhostwriterOptions(arguments: Array(CommandLine.arguments.dropFirst()))
      if options.showHelp {
        print(helpText)
        return
      }

      let source = try PremiseGhostwriter.render(options.request)
      print(source)
    } catch {
      fputs("premise-ghostwriter: \(error)\n", stderr)
      fputs("Run `swift package premise-ghostwriter --help` for usage.\n", stderr)
      Foundation.exit(1)
    }
  }

  private static let helpText = """
    Usage:
      swift package premise-ghostwriter --kind fuzz-no-crash --module MyApp --type Payload --strategy 'Strategy<Payload>.payloads()' --subject 'try parse($0)'
      swift package premise-ghostwriter --kind roundtrip --module MyApp --type Payload --strategy 'Strategy<Payload>.payloads()' --encode 'try JSONEncoder().encode($0)' --decode 'try JSONDecoder().decode(Payload.self, from: $0)'
      swift package premise-ghostwriter --kind equivalence --module MyApp --type Payload --strategy 'Strategy<Payload>.payloads()' --subject 'try newImpl($0)' --alternate 'try oldImpl($0)'
      swift package premise-ghostwriter --kind idempotence --module MyApp --type Payload --strategy 'Strategy<Payload>.payloads()' --subject 'try normalize($0)'
      swift package premise-ghostwriter --kind binary-operation-laws --module MyApp --type Value --strategy 'Strategy<Value>.values()' --operation 'combine($0, $1)' --identity 'Value.empty'

    Options:
      --kind        One of: fuzz-no-crash (or fuzz), roundtrip, equivalence, idempotence, binary-operation-laws
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
    var kind: GhostwriterTemplateKind?
    var moduleName: String?
    var typeName: String?
    var strategyExpression: String?
    var testName: String?
    var subjectExpression: String?
    var alternateExpression: String?
    var encodeExpression: String?
    var decodeExpression: String?
    var operationExpression: String?
    var identityExpression: String?
    var equalityExpression = "$0 == $1"
    var showHelp = false

    var iterator = arguments.makeIterator()
    while let argument = iterator.next() {
      switch argument {
      case "--help", "-h":
        showHelp = true
      case "--kind":
        kind = try Self.parseKind(Self.nextValue(&iterator, after: argument))
      case "--module":
        moduleName = try Self.nextValue(&iterator, after: argument)
      case "--type":
        typeName = try Self.nextValue(&iterator, after: argument)
      case "--strategy":
        strategyExpression = try Self.nextValue(&iterator, after: argument)
      case "--test-name":
        testName = try Self.nextValue(&iterator, after: argument)
      case "--subject":
        subjectExpression = try Self.nextValue(&iterator, after: argument)
      case "--alternate":
        alternateExpression = try Self.nextValue(&iterator, after: argument)
      case "--encode":
        encodeExpression = try Self.nextValue(&iterator, after: argument)
      case "--decode":
        decodeExpression = try Self.nextValue(&iterator, after: argument)
      case "--operation":
        operationExpression = try Self.nextValue(&iterator, after: argument)
      case "--identity":
        identityExpression = try Self.nextValue(&iterator, after: argument)
      case "--equality":
        equalityExpression = try Self.nextValue(&iterator, after: argument)
      default:
        throw GhostwriterCLIError.unknownArgument(argument)
      }
    }

    self.showHelp = showHelp
    if showHelp {
      request = GhostwriterRequest(
        kind: .fuzzNoCrash,
        moduleName: "ModuleUnderTest",
        typeName: "Value",
        strategyExpression: "Strategy<Value>.values()"
      )
      return
    }

    request = GhostwriterRequest(
      kind: try Self.require(kind, "--kind"),
      moduleName: try Self.require(moduleName, "--module"),
      typeName: try Self.require(typeName, "--type"),
      strategyExpression: try Self.require(strategyExpression, "--strategy"),
      testName: testName,
      subjectExpression: subjectExpression,
      alternateExpression: alternateExpression,
      encodeExpression: encodeExpression,
      decodeExpression: decodeExpression,
      operationExpression: operationExpression,
      identityExpression: identityExpression,
      equalityExpression: equalityExpression
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

  private static func require<Value>(_ value: Value?, _ option: String) throws -> Value {
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
