import PremiseCore
import PremiseStrategies

let productStrategy = Strategy<Product>(
  label: "product",
  draw: { data in
    // Wrapping in withSpan lets the ShrinkMachine treat the entire
    // Product as a unit when it appears inside a collection.
    try data.withSpan("product") { d in
      let nameLength = d.drawInteger(in: 3...30)
      let name = String(
        (0..<nameLength).map { _ -> Character in
          Character(UnicodeScalar(UInt8(97 + d.drawInteger(in: 0...25))))
        }
      )
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
  }
)
