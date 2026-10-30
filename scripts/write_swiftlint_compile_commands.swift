import Foundation

func command() -> Int32 {
  let arguments = Array(CommandLine.arguments.dropFirst())
  guard arguments.count == 4 else {
    report(
      "Expected repository root, target debug directory, output path, "
        + "and cflags path.\n"
    )
    return 64
  }
  do {
    try generate(arguments)
    return 0
  } catch {
    report("Unable to write SwiftLint compile commands: \(error)\n")
    return 1
  }
}

private func generate(_ arguments: [String]) throws {
  let root = URL(fileURLWithPath: arguments[0]).standardizedFileURL
  let buildDirectory = URL(fileURLWithPath: arguments[1]).standardizedFileURL
  let output = URL(fileURLWithPath: arguments[2]).standardizedFileURL
  let cflags = try String(contentsOfFile: arguments[3], encoding: .utf8)
    .split(separator: "\n").map(String.init)
  let records = try records(
    in: root,
    buildDirectory: buildDirectory,
    cflags: cflags
  )
  try write(records, to: output)
}
private func records(
  in root: URL,
  buildDirectory: URL,
  cflags: [String]
) throws -> [[String: Any]] {
  let descriptionURL =
    buildDirectory
    .appendingPathComponent("description.json")
  let modulesURL = buildDirectory.appendingPathComponent("Modules")
  guard FileManager.default.fileExists(atPath: modulesURL.path) else {
    throw CocoaError(.fileNoSuchFile)
  }
  let data = try Data(contentsOf: descriptionURL)
  let object = try JSONSerialization.jsonObject(with: data)
  guard let values = object as? [String: Any],
    let commands = values["swiftCommands"] as? [String: Any]
  else {
    throw CocoaError(.fileReadCorruptFile)
  }
  return commands.values.flatMap { command in
    guard let value = command as? [String: Any] else {
      return [[String: Any]]()
    }
    return records(for: value, root: root, cflags: cflags)
  }
}

private func analyzerArguments(from arguments: [String]) -> [String] {
  var filtered: [String] = []
  var index = arguments.startIndex
  while index < arguments.endIndex {
    if let range = indexingFrontendFlagRange(in: arguments, at: index) {
      index = range.upperBound
    } else {
      filtered.append(arguments[index])
      index += 1
    }
  }
  return filtered
}

private func indexingFrontendFlagRange(
  in arguments: [String],
  at index: Int
) -> Range<Int>? {
  let next = index + 1
  guard arguments[index] == "-Xfrontend", next < arguments.endIndex else {
    return nil
  }
  let disabledFlags = [
    "-experimental-lazy-typecheck",
    "-experimental-skip-all-function-bodies",
    "-experimental-allow-module-with-compiler-errors",
    "-empty-abi-descriptor",
  ]
  guard disabledFlags.contains(arguments[next]) else {
    return nil
  }
  return index..<(next + 1)
}

private struct TargetCommand {
  let arguments: [String]
  let importPath: String
  let moduleName: String
  let sourceFiles: [String]
  let cflags: [String]
}

private func records(
  for command: [String: Any],
  root: URL,
  cflags: [String]
) -> [[String: Any]] {
  guard let arguments = command["otherArguments"] as? [String],
    let sourceFiles = command["sources"] as? [String],
    let importPath = command["importPath"] as? String,
    let moduleName = command["moduleName"] as? String
  else {
    return []
  }
  let target = TargetCommand(
    arguments: arguments,
    importPath: importPath,
    moduleName: moduleName,
    sourceFiles: sourceFiles,
    cflags: cflags
  )
  return
    sourceFiles
    .filter { isSource($0, in: root) }
    .map { record(source: $0, target: target, root: root) }
}

private func isSource(_ path: String, in root: URL) -> Bool {
  let sourceRoot =
    root.resolvingSymlinksInPath()
    .appendingPathComponent("Sources").path + "/"
  let source = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
  return path.hasSuffix(".swift") && source.hasPrefix(sourceRoot)
}

private func record(
  source: String,
  target: TargetCommand,
  root: URL
) -> [String: Any] {
  let indexPath = URL(fileURLWithPath: target.importPath)
    .deletingLastPathComponent()
    .appendingPathComponent("index/store")
    .path
  let arguments =
    analyzerArguments(from: target.arguments)
    + ["-I", target.importPath, "-module-name", target.moduleName]
    + ["-index-store-path", indexPath] + z3Arguments(target: target, root: root)
    + target.sourceFiles
  let command = commandLine(arguments: arguments)
  return [
    "directory": root.path,
    "file": source,
    "arguments": ["swiftc"] + arguments,
    "command": command,
  ]
}

private func z3Arguments(target: TargetCommand, root: URL) -> [String] {
  guard target.moduleName == "PremiseSMT" else { return [] }
  let moduleMap = root.appendingPathComponent(
    "Sources/CZ3/module.modulemap"
  ).path
  return ["-Xcc", "-fmodule-map-file=\(moduleMap)"]
    + target.cflags.flatMap { ["-Xcc", $0] }
}
private func commandLine(arguments: [String]) -> String {
  (["swiftc"] + arguments).map(shellQuote).joined(separator: " ")
}

private func shellQuote(_ argument: String) -> String {
  "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

private func write(_ records: [[String: Any]], to output: URL) throws {
  guard !records.isEmpty else {
    report("No Swift source compile commands found.\n")
    throw CocoaError(.fileReadCorruptFile)
  }
  let data = try JSONSerialization.data(
    withJSONObject: records,
    options: [.prettyPrinted, .sortedKeys]
  )
  try data.write(to: output)
}

private func report(_ message: String) {
  FileHandle.standardError.write(Data(message.utf8))
}

exit(command())
