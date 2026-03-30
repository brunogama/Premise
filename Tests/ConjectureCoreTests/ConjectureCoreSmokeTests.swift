import Testing
@testable import ConjectureCore

@Test("ConjectureCore module imports")
func conjectureCoreModuleImports() {
  #expect(ConjectureCoreModule.name == "ConjectureCore")
}
