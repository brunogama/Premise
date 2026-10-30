import PremiseCore
import PremiseStrategies

func shrinkCandidate(_ product: Product, price: Int, stock: Int) -> Product {
  Product(
    name: product.name,
    priceCents: price,
    category: product.category,
    stock: stock
  )
}

let minimalProduct = Product(
  name: "aaa",
  priceCents: 0,
  category: .electronics,
  stock: 0
)

extension Strategy where Value == Product {
  static var products: Strategy<Product> {
    Strategy<Product>(
      label: "product",
      draw: { data in
        data.withSpan("product") { spanData in
          let nameLen = spanData.drawInteger(in: 3...30)
          let name = String(repeating: "a", count: nameLen)
          let price = spanData.drawInteger(in: 0...9_999)
          let catIndex = spanData.drawInteger(
            in: 0...(Category.allCases.count - 1)
          )
          let stock = spanData.drawInteger(in: 0...1000)
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
            shrinkCandidate(product, price: 0, stock: product.stock)
          )
        }
        if product.stock > 0 {
          candidates.append(
            shrinkCandidate(product, price: product.priceCents, stock: 0)
          )
        }
        candidates.append(minimalProduct)
        return candidates
      }
    )
  }
}
