import PremiseCore
import PremiseStrategies

extension Strategy where Value == Product {
  static var products: Strategy<Product> { /* ... as above ... */
    .just(Product(name: "aaa", priceCents: 100, category: .electronics, stock: 1))
  }

  static var freeProducts: Strategy<Product> {
    products.map {
      Product(
        name: $0.name,
        priceCents: 0,
        category: $0.category,
        stock: $0.stock
      )
    }
  }

  static var outOfStockProducts: Strategy<Product> {
    products.map {
      Product(
        name: $0.name,
        priceCents: $0.priceCents,
        category: $0.category,
        stock: 0
      )
    }
  }

  static func expensiveProducts(minimumCents: Int = 5_000) -> Strategy<Product> {
    Strategy<Int>.integers(in: minimumCents...99_999)
      .map { price in
        Product(name: "premium", priceCents: price, category: .electronics, stock: 1)
      }
  }
}
