import PremiseCore
import PremiseStrategies

let productStrategy = Strategy<Product>(
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

    // Try reducing to free first (price 0 is the identity for discounts)
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
    // Try reducing stock to 0
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
    // Try simplest possible product
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
