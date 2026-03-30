import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct PremiseMacrosPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    GivenMacro.self
  ]
}
