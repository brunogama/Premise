import Testing
@testable import PremiseCore

@Test("PremiseCore module imports")
func premiseCoreModuleImports() {
  #expect(PremiseCoreModule.name == "PremiseCore")
}
