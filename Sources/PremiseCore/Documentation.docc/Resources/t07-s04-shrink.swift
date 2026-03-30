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
  shrink: { _ in
    // Return the minimal Product as the first shrink candidate.
    [Product(name: "aaa", priceCents: 0, category: .electronics, stock: 0)]
  }
)
