import Testing
import PremiseTesting
import PremiseStrategies

@Test func discountNeverProducesNegativePrice() async throws {
  try await forAll(.products) { product in
    for discount in 0...100 {
      let discounted = product.discountedPrice(percent: discount)
      #expect(discounted >= 0, "discount \(discount)% on \(product) gave \(discounted)")
    }
  }
}
