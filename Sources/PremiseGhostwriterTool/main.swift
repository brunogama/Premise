import Foundation
import PremiseGhostwriter

@main
struct PremiseGhostwriterTool {
  static func main() {
    do {
      let options = try GhostwriterOptions(arguments: Array(CommandLine.arguments.dropFirst()))
      if options.showHelp {
        emit(helpText)
        return
      }

      let source = try PremiseGhostwriter.render(options.request)
      emit(source)
    } catch {
      logError("premise-ghostwriter: \(error)")
      logError("Run `swift package premise-ghostwriter --help` for usage.")
      Foundation.exit(1)
    }
  }

  // Generated source is the tool's product; write it through FileHandle so the
  // tool never touches C stdio globals.
  private static func emit(_ message: String) {
    try? FileHandle.standardOutput.write(contentsOf: Data("\(message)\n".utf8))
  }

  // Writes through FileHandle rather than Glibc's `stderr`, which is a global
  // `var` that Swift 6 strict concurrency rejects on Linux.
  private static func logError(_ message: String) {
    try? FileHandle.standardError.write(contentsOf: Data("\(message)\n".utf8))
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

  init(arguments: [String]) throws {
    var values: [String: String] = [:]
    var iterator = arguments.makeIterator()
    while let argument = iterator.next() {
      switch argument {
      case "--help", "-h":
        showHelp = true

      case let option where Self.valueOptions.contains(option):
        values[option] = try Self.nextValue(&iterator, after: option)

      default:
        throw GhostwriterCLIError.unknownArgument(argument)
      }
    }

    request = showHelp ? Self.makeHelpPlaceholderRequest() : try Self.makeRequest(from: values)
  }

  private static let valueOptions: Set<String> = [
    "--kind", "--module", "--type", "--strategy", "--test-name", "--subject",
    "--alternate", "--encode", "--decode", "--operation", "--identity", "--equality",
  ]

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

  private static func makeRequest(from values: [String: String]) throws -> GhostwriterRequest {
    GhostwriterRequest(
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
