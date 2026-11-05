import PremiseCore
import PremiseStrategies

func drawProductName(_ data: inout PremiseData) -> String {
  let nameLength = data.drawInteger(in: 3...30)
  return String(
    (0..<nameLength).map { _ -> Character in
      Character(UnicodeScalar(UInt8(97 + data.drawInteger(in: 0...25))))
    }
  )
}

let productStrategy = Strategy<Product>(
  label: "product",
  draw: { data in
    // Wrapping in withSpan lets the ShrinkMachine treat the entire
    // Product as a unit when it appears inside a collection.
    data.withSpan("product") { spanData in
      let name = drawProductName(&spanData)
      let price = spanData.drawInteger(in: 0...9_999)
      let catIndex = spanData.drawInteger(in: 0...(Category.allCases.count - 1))
      let stock = spanData.drawInteger(in: 0...1000)
      return Product(
        name: name,
        priceCents: price,
        category: Category.allCases[catIndex],
        stock: stock
      )
    }
  }
)
