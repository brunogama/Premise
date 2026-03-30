import Testing
@testable import PremiseStrategies

@Test("PremiseStrategies module imports")
func premiseStrategiesModuleImports() {
  #expect(PremiseStrategiesModule.name == "PremiseStrategies")
}
