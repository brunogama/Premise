import Foundation
import PackagePlugin

@main
struct PremiseGhostwriterPlugin: CommandPlugin {
  func performCommand(
    context: PluginContext,
    arguments: [String]
  ) async throws {
    let tool = try context.tool(named: "PremiseGhostwriterTool")
    let process = Process()
    process.executableURL = tool.url
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()

    guard process.terminationReason == .exit,
      process.terminationStatus == 0
    else {
      throw PremiseGhostwriterPluginError.toolFailed(process.terminationStatus)
    }
  }
}

enum PremiseGhostwriterPluginError: Error, CustomStringConvertible {
  case toolFailed(Int32)

  var description: String {
    switch self {
    case .toolFailed(let status):
      return "PremiseGhostwriterTool failed with exit status \(status)."
    }
  }
}
