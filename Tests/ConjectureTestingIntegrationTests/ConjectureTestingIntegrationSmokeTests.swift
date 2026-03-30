import Testing
@testable import ConjectureTesting

@Test("ConjectureTesting module imports")
func conjectureTestingModuleImports() {
  #expect(ConjectureTestingModule.name == "ConjectureTesting")
}
