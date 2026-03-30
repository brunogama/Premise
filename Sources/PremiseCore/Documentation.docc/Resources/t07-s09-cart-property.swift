import Testing
import PremiseTesting
import PremiseStrategies

@Test func discountNeverProducesNegativePrice() async throws {
  try await forAll(.products) { product in
    for discount in 0...100 {
      #expect(product.discountedPrice(percent: discount) >= 0)
    }
  }
}

@Test func bulkDiscountNeverExceedsFullPrice() async throws {
  let cartStrategy = Strategy<[Product]>.arrays(of: .products, length: 1...20)
  let discountStrategy = Strategy<Int>.integers(in: 0...50)  // up to 50% off

  try await forAll(cartStrategy) { cart in
    try await forAll(discountStrategy) { discountPercent in
      let fullTotal = cart.reduce(0) { $0 + $1.priceCents }
      let discountedTotal = cart.reduce(0) { $0 + $1.discountedPrice(percent: discountPercent) }

      #expect(
        discountedTotal <= fullTotal,
        "Discounted total \(discountedTotal) exceeded full total \(fullTotal)"
      )
    }
  }
}
