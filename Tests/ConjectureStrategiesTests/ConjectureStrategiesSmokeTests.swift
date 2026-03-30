import Testing
@testable import ConjectureStrategies

@Test("ConjectureStrategies module imports")
func conjectureStrategiesModuleImports() {
  #expect(ConjectureStrategiesModule.name == "ConjectureStrategies")
}
