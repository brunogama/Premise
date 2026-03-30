import Testing
@testable import PremiseDatabase

@Test("PremiseDatabase module imports")
func premiseDatabaseModuleImports() {
  #expect(PremiseDatabaseModule.name == "PremiseDatabase")
}
