import Foundation

enum RepositoryQA {
  static func command() -> Int32 {
    let failures = policyFailures(in: repositoryRoot())
    let destination =
      failures.isEmpty
      ? FileHandle.standardOutput
      : FileHandle.standardError
    destination.write(Data(output(for: failures).utf8))
    return failures.isEmpty ? 0 : 1
  }

  private static func repositoryRoot() -> URL {
    let path = CommandLine.arguments.dropFirst().first ?? "."
    return URL(fileURLWithPath: path)
  }

  private static func policyFailures(in root: URL) -> [String] {
    [
      formatIndentationFailure(in: root),
      policyFailure(
        in: root,
        fileName: ".swiftlint.yml",
        expectedFragment: [
          "indentation_width:",
          "  severity: error",
          "  indentation_width: 2",
        ].joined(separator: "\n")
      ),
    ].compactMap { $0 }
  }

  private static func formatIndentationFailure(in root: URL) -> String? {
    let file = root.appendingPathComponent(".swift-format")
    guard let data = try? Data(contentsOf: file) else {
      return "Missing or unreadable: .swift-format"
    }
    guard let object = try? JSONSerialization.jsonObject(with: data),
      let values = object as? [String: Any],
      let indentation = values["indentation"] as? [String: Any],
      let spaces = indentation["spaces"] as? Int, spaces == 2
    else {
      return "Two-space indentation is not configured in .swift-format"
    }
    return nil
  }
  private static func policyFailure(
    in root: URL,
    fileName: String,
    expectedFragment: String
  ) -> String? {
    let file = root.appendingPathComponent(fileName)
    guard let content = try? String(contentsOf: file, encoding: .utf8) else {
      return "Missing or unreadable: \(fileName)"
    }
    guard content.contains(expectedFragment) else {
      return "Two-space indentation is not configured in \(fileName)"
    }
    return nil
  }

  private static func output(for failures: [String]) -> String {
    guard failures.isEmpty else {
      return "QA: FAIL\n\(failures.joined(separator: "\n"))\n"
    }
    return "QA: PASS\n"
  }
}

exit(RepositoryQA.command())
