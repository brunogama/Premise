import PremiseCore
import PremiseStrategies

extension Strategy where Value == Product {
  static var products: Strategy<Product> {
    Strategy<Product>(
      label: "product",
      draw: { data in
        try data.withSpan("product") { d in
          let nameLen = d.drawInteger(in: 3...30)
          let name = String(repeating: "a", count: nameLen)
          let price = d.drawInteger(in: 0...9_999)
          let catIndex = d.drawInteger(in: 0...(Category.allCases.count - 1))
          let stock = d.drawInteger(in: 0...1000)
          return Product(
            name: name,
            priceCents: price,
            category: Category.allCases[catIndex],
            stock: stock
          )
        }
      },
      shrink: { product in
        var candidates: [Product] = []
        if product.priceCents > 0 {
          candidates.append(
            Product(
              name: product.name,
              priceCents: 0,
              category: product.category,
              stock: product.stock
            )
          )
        }
        if product.stock > 0 {
          candidates.append(
            Product(
              name: product.name,
              priceCents: product.priceCents,
              category: product.category,
              stock: 0
            )
          )
        }
        candidates.append(
          Product(
            name: "aaa",
            priceCents: 0,
            category: .electronics,
            stock: 0
          )
        )
        return candidates
      }
    )
  }
}
