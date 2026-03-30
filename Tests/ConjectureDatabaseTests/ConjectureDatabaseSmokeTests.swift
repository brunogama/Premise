import Testing
@testable import ConjectureDatabase

@Test("ConjectureDatabase module imports")
func conjectureDatabaseModuleImports() {
  #expect(ConjectureDatabaseModule.name == "ConjectureDatabase")
}
