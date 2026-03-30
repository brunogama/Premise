import Testing
@testable import PremiseTesting

@Test("PremiseTesting module imports")
func premiseTestingModuleImports() {
  #expect(PremiseTestingModule.name == "PremiseTesting")
}
