import Foundation
import PackagePlugin

@main
struct PremiseReplayPlugin: CommandPlugin {
  func performCommand(
    context: PluginContext,
    arguments: [String]
  ) async throws {
    let tool = try context.tool(named: "PremiseReplayTool")
    let process = Process()
    process.executableURL = tool.url
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()

    guard process.terminationReason == .exit,
      process.terminationStatus == 0
    else {
      throw PremiseReplayPluginError.toolFailed(process.terminationStatus)
    }
  }
}

enum PremiseReplayPluginError: Error, CustomStringConvertible {
  case toolFailed(Int32)

  var description: String {
    switch self {
    case .toolFailed(let status):
      return "PremiseReplayTool failed with exit status \(status)."
    }
  }
}
